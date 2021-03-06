require "bundler/setup"
$LOAD_PATH << File.expand_path("../lib", __FILE__)
require "twostroke"
T = Twostroke::Runtime::Types
require "paint"
require "coderay"

bytecode = {}
vm = Twostroke::Runtime::VM.new bytecode
Twostroke::Runtime::Lib.setup_environment vm

def repl_inspect(obj)
  if obj.is_a? T::String
    Paint[obj.string.inspect, :green]
  elsif obj.is_a? T::Number
    Paint[obj.number.inspect, :blue, :bright]
  elsif obj.is_a? T::Boolean
    Paint[obj.boolean.inspect, :cyan, :bright]
  elsif obj.is_a? T::Null
    Paint["null", :yellow]
  elsif obj.is_a? T::Undefined
    Paint["undefined", :yellow]
  elsif obj.is_a? T::Function
    Paint[obj.name.empty? ? "[Function]" : "[Function: #{obj.name}]", :cyan]
  elsif obj.is_a? T::RegExp
    Paint[obj.regexp.inspect + (obj.global ? "g" : ""), :bright, :red]
  elsif obj.is_a? T::Array
    "[#{obj.items.reject(&:nil?).map(&method(:repl_inspect)).join(", ")}]"
  elsif obj.is_a? T::Object and obj._class == T::Object.constructor_function
    "{ #{obj.enum_for(:each_enumerable_property).map { |k| Paint[k, :magenta] + ": " + repl_inspect(obj.get(k)) }.join ", "} }"
  else
    Twostroke::Runtime::Types.to_string(obj).string
  end
end

ARGV.reject { |inc| inc =~ /^--/ }.each do |inc|
  parser = Twostroke::Parser.new(Twostroke::Lexer.new(File.read inc))
  parser.parse

  compiler = Twostroke::Compiler::TSASM.new parser.statements, "include_#{inc}_"
  compiler.compile

  compiler.bytecode.each do |k,v|
    bytecode[k] = v
  end
  
  vm.execute :"include_#{inc}_main", vm.global_scope
end

sect = 0

trap "SIGINT" do
  print "\r"
  system "stty -raw echo"
  exit!
end

loop do
  src = ""
  system "stty raw -echo"
  print Paint[">>> ", :bright]
  loop do
    c = STDIN.getc
    if c.ord == 3
      # ctrl+c
      if src.empty?
        print "\r"
        system "stty -raw echo"
        exit!
      else
        print "\r    #{' ' * src.size}"
        src = ""
      end
    elsif c.ord == 127
      # backspace
      src = src[0...-1]
      print "\e[1D \e[1D"
    elsif c.ord == 24
      # ctrl+x
      src = ""
    elsif c.ord == 13
      # enter
      break
    elsif c =~ /[[:print:]]/
      src << c
    end
    print "\r"
    print Paint[">>> ", :bright]
    print CodeRay.scan(src, :javascript).encode :terminal
  end
  system "stty -raw echo"
  puts
  src << ";"

  begin
    parser = Twostroke::Parser.new(Twostroke::Lexer.new(src))
    parser.parse
  
    sect += 1
    compiler = Twostroke::Compiler::TSASM.new parser.statements, "repl_#{sect}_"
    compiler.compile
  
    compiler.bytecode.each do |k,v|
      bytecode[k] = v
    end
  
    bytecode[:"repl_#{sect}_main"][-2] = [:ret] # hacky way to make main return the last evaluated value
    obj = nil
    exception = catch(:exception) { obj = vm.execute(:"repl_#{sect}_main", vm.global_scope) || Twostroke::Runtime::Types::Undefined.new; nil }
    if exception
      obj = exception
      vm.global_scope.set_var "$EX", obj
    else  
      vm.global_scope.set_var "$_", obj
    end
    str = repl_inspect obj    
    if exception
      print Paint["!!!", :white, :red] + " "
    else
      print " => "
    end
    puts str
  rescue => e
    if ARGV.include? "--debug"
      puts "#{e.class.name}: #{e.message}"
      e.backtrace.each { |s| puts "  #{s}" }
    else
      puts "#{e.class.name}: #{e.message}"
    end
  end
end


=begin
vm = Twostroke::Runtime::VM.new compiler.bytecode
Twostroke::Runtime::Lib.setup_environment vm.global_scope

if ARGV.include? "--pry"
  require "pry"
  pry binding
end

vm.execute
=end
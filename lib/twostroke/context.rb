module Twostroke
  class Context
    attr_reader :vm
    
    def initialize
      @ai = 0
      @vm = Twostroke::Runtime::VM.new({})
      Twostroke::Runtime::Lib.setup_environment vm
    end
    
    def [](var)
      vm.global_scope.get_var(var.intern).to_ruby
    end
    
    def []=(name, value)
      vm.global_scope.set_var(name.intern, Twostroke::Runtime::Types.marshal(value))
      return value
    end

    def raw_eval(src, scope = vm.global_scope.close)
      prefix = make_prefix
      bytecode = compile src, prefix
      main = :"#{prefix}main"
      bytecode[main][-2] = [:ret]
      vm.bytecode.merge! bytecode
      vm.execute main, scope
    end  
    
    def eval(src)
      if result = raw_eval(src.to_s + ";")
        result.to_ruby
      end
    end
    
    def raw_exec(src, scope = nil)
      prefix = make_prefix
      bytecode = compile src, prefix
      vm.bytecode.merge! bytecode
      vm.execute :"#{prefix}main", scope
    end
    
    def exec(src)
      raw_exec(src).to_ruby
    end
    
    def inspect
      to_s
    end
    
  private  
    def make_prefix
      "#{@ai += 1}_".intern
    end
  
    def compile(src, prefix)
      parser = Twostroke::Parser.new Twostroke::Lexer.new src
      parser.parse
      compiler = Twostroke::Compiler::TSASM.new parser.statements, prefix
      compiler.compile
      compiler.bytecode
    end
  end
end

require "twostroke/context/object_proxy"
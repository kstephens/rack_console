require 'time'
require 'date'

module RackConsole
  module ExprHelpers
    def expr_for_object! obj, mod = nil, kind = nil
      @result = result_capture! do
        @expr = expr_for_object obj, mod, kind
        obj
      end
      @result_evaled = true
      @result_ok = true
    end
    
    def expr_for_object obj, mod = nil, kind = nil
      case obj
      when nil, true, false
        obj.to_s
      when Float, Integer
        obj.inspect
      when Time
        "Time.parse(#{obj.iso8601(6).inspect})"
      when Date
        "Date.parse(#{obj.to_s.inspect})"
      when Module
        expr_for_object obj
      when Method, UnboundMethod
        expr_for_method(mod, obj.name, kind) if mod && kind
      else
        nil
      end
    end

    def expr_for_method mod, name, kind
      "#{mod}.#{kind}(#{name.to_sym.inspect})"
    end

    def expr_for_Module obj
      obj && obj.name
    end
  end
end


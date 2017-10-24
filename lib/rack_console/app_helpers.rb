require 'active_support/core_ext/class/subclasses'
require 'active_support/core_ext/object/blank'
require 'stringio'
require 'rack_console/expr_helpers'
require 'rack_console/configuration'
require 'rack_console/method_introspection'
require 'rack_console/formatting'

module RackConsole
  module AppHelpers
    include ExprHelpers, Configuration, MethodIntrospection, Formatting

    def with_access
      if has_console_access?
        yield
      else
        raise Error, "not authorized"
      end
    end

    def console!
      haml :console, locals: locals, layout: layout
    end

    def evaluate_expr!
      return if @result_evaled
      result_capture! do
        @stdin  = StringIO.new('')
        @stdout = StringIO.new('')
        @stderr = StringIO.new('')
        @result_ok = false
        @expr = (params[:expr] || '').strip
        unless @expr.blank?
          @result_evaled = true
          Timeout.timeout(config[:eval_timeout] || 120) do
            capture_stdio! do
              @result = eval_expr(eval_target, @expr)
              @result_ok = true
            end
          end
        end
      end
    end

    def eval_expr et, expr
      expr_str = "begin; #{@expr} \n; end"
      case et
      when nil, false
        eval(expr_str)
      when Module
        et.module_eval(expr_str)
      else
        et.instance_eval(expr_str)
      end
    end

    def evaluate_module!
      evaluate_expr!
      @show_stdio = @show_result = false
      if @result_ok && @result.is_a?(Module)
        result_capture! do
          @module = @result
          expr_for_object! @module
        end
      end
    end

    def evaluate_method!
      evaluate_expr!
      @show_stdio = @show_result = false
      if @result_ok && @result.is_a?(Module)
        result_capture! do
          @module = @result
          @method_name = params[:name]
          @method_kind = params[:kind].to_s =~ /i/ ? :instance_method : :method
          @method = @module.send(@method_kind, @method_name) rescue nil
          unless @method
            @method = @module.send(:method, @method_name)
            @method_kind = :method
          end
          @result = @method
          expr_for_object! @method, @module, @method_kind
        end
      end
    end

    def capture_stdio!
      @captured_stdio = true
      _stdin, _stdout, _stderr = $stdin, $stdout, $stderr
      $stdin, $stdout, $stderr = @stdin, @stdout, @stderr
      begin
        yield
      ensure
        $stdin, $stdout, $stderr = _stdin, _stdout, _stderr
      end
    end

    def evaluate_methods!
      @methods = nil
      result_capture! do
        @methods = methods_matching(params)
      end
    end

    def prepare_file!
      path = params[:splat][0]
      file, line = href_to_file_line(path)
      result_capture! do
        unless has_file_access? file
          content_type 'text/plain'
          return "NOT A LOADABLE FILE"
        end
        @source_file = SourceFile.new([ file, line ]).load!
      end
    end

    def result_capture!
      @result_ok = false
      result = yield
      @result_ok = true
      result
    rescue ::StandardError, ::ScriptError
      @error = $!
      @error_description = @error.inspect
    ensure
      @result_extended = @result.singleton_class.included_modules rescue nil
      @result_class = @result.class.name
      if @is_module = (::Module === @result)
        @module = @result
        @ancestors = @module.ancestors.drop(1)
        if @is_class = (::Class === @module)
          @superclass = @module.superclass
          @subclasses = @module.subclasses.sort_by{|c| c.name || ''}
        end
        @constants = @module.constants(false).sort.map{|n| [ n, const_get_safe(@module, n) ]}
        @methods = methods_for_module(@module)
      end
      if @is_method = (::Method === @result || ::UnboundMethod === @result || MockMethod === @result)
        @method = @result
        @method_source_location = @method.source_location
        @method_source = @method_source_location && SourceFile.new(@method_source_location).load!.narrow_to_block!
      end
    end

    def const_get_safe m, name
      m.const_get(name)
    rescue Object
      "ERROR: #{$!.inspect}"
    end

  end
end

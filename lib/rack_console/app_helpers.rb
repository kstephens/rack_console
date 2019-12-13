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

    def css_dir
      config[:css_dir]
    end

    def js_dir
      config[:js_dir]
    end

    def eval_context
      case context = config[:eval_context]
      when Proc
        context.call
      else
        context
      end
    end
    
    ###############################

    def check_access!
      unauthorized! unless has_console_access?
    end

    def unauthorized!
      raise Error, "not authorized"
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

=begin
    def each_module &blk
      ObjectSpace.each_object(::Module, &blk)
    end
=end
    def each_module &blk
      (@@each_module ||= find_modules(::Object)).each(&blk)
    end
    @@each_module = nil

    def find_modules mod
      acc = Set.new
      stack = [ mod ]
      while m = stack.pop
        unless acc.include?(m)
          acc << m
          m.constants.each do | name |
            val = begin
                    const_get_safe(m, name)
                  rescue Object
                    nil
                  end
            stack << val if Module === val
          end
        end
      end
      acc = acc.to_a
      acc
    end

    # const_get can cause all sorts of autoload behavior.
    # Therefore we temporarly disable code loading methods.
    def const_get_safe m, name
      neuter_method(::Kernel, :load, :require, :require_relative) do
        m.const_get(name)
      end
    rescue Object
      "ERROR: #{$!.inspect}"
    end

    def neuter_method mod, *names
      save_names = { }
      names.each do | name |
        save_name = save_names[name] = :"neuter_method_#{@@method_name_counter += 1}"
        mod.alias_method save_name, name
      end
      begin
        names.each do | name |
          mod.define_method(name) {|*args| nil}
        end
        yield
      ensure
        save_names.each do | name, save_name |
          mod.alias_method name, save_name
          mod.remove_method save_name
        end
      end
    end
    @@method_name_counter = 0
    
    extend self
  end
end

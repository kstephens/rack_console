require 'active_support/core_ext/class/subclasses'
require 'active_support/core_ext/object/blank'
require 'pp'

module RackConsole
  module AppHelpers
    def console!
      if has_console_access?
        haml :console, locals: locals # , :layout => false
      else
        raise "not authorized"
      end
    end

    def evaluate_expr!
      result_capture! do
        @stdin  = StringIO.new('')
        @stdout = StringIO.new('')
        @stderr = StringIO.new('')
        @result_ok = false
        @expr = (params[:expr] || '').strip
        unless @expr.blank?
          @result_evaled = true
          Timeout.timeout(30) do
            _stdin, _stdout, _stderr = $stdin, $stdout, $stderr
            $stdin, $stdout, $stderr = @stdin, @stdout, @stderr
            begin
              @result = eval("begin; #{@expr}; end")
              @result_ok = true
            ensure
              $stdin, $stdout, $stderr = _stdin, _stdout, _stderr
            end
          end
        end
      end
    end

    def evaluate_module!
      evaluate_expr!
      if @result_ok && @result.is_a?(Module)
        result_capture! do
          @module = @result
          @ancestors = @module.ancestors.drop(1)
          if @is_class = @module.is_a?(Class)
            @superclass = @module.superclass
            @subclasses = @module.subclasses.sort_by{|c| c.name || ''}
          end
          @singleton_methods = @module.methods(false).sort.map{|n| @module.method(n) }
          @instance_method_names = (@module.instance_methods(false) | @module.private_instance_methods(false) | @module.protected_instance_methods(false)).sort
          @instance_methods  = @instance_method_names.map{|n| @module.instance_method(n) }
          @constants = @module.constants(false).sort.map{|n| [ n, const_get_safe(@module, n) ]}
        end
      end
    end

    def evaluate_method!
      evaluate_expr!
      if @result_ok && @result.is_a?(Module)
        result_capture! do
          @module = @result
          @method_name = params[:name]
          @method_kind = params[:kind] =~ /instance/ ? :instance_method : :method
          @method = @module.send(@method_kind, @method_name) rescue nil
          unless @method
            @method = @module.send(:method, @method_name)
            @method_kind = :method
          end
          @method_source_location = @method.source_location
          @method_source = @method_source_location && SourceFile.new(@method_source_location).load!.narrow_to_block!
          @result = @method
        end
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
    rescue
      @error = $!
      @error_description = @error.inspect
    ensure
      @result_extended = @result.singleton_class.included_modules rescue nil
      @result_class = @result.class.name
    end

    def const_get_safe m, name
      m.const_get(name)
    rescue Object
      "ERROR: #{$!.inspect}"
    end

    def format_source_location source_location, meth = nil, kind = nil, owner = nil
      file, line = source_location
      if file
        "<a href='#{file_line_to_href file, line}' class='file_name'>#{file_name_tag("#{file}:#{line}")}</a>"
      else
        if meth
          # Assume meth is Ruby Core and link to rdocs on ruby-doc.org.
          name = meth.name
          owner ||= meth.owner
          owner_name = (owner.name || '').gsub('::', '/')
          kind &&= (owner.instance_method(name) rescue nil) ? :instance_method : :method
          kind = kind == :method ? 'c' : 'i'
          a_name = name.to_s.gsub(/([^a-z0-9_])/i){|m| "-%X" % [ m.ord ]}
          a_name.sub!(/^-/, '')
          a_name = "method-#{kind}-#{a_name}"
          ruby_core_link = "http://www.ruby-doc.org/core-#{RUBY_VERSION}/#{owner_name}.html\##{a_name}"
          "<a href='#{ruby_core_link}' class='ruby_core_doc'>#{h ruby_core_link}</a>"
        else
          "NONE"
        end
      end
    end

    def methods_matching params
      name_p  = params[:name]
      kind_p  = params[:kind]
      owner_p = params[:owner]

      name_p  &&= name_p  != '*' && name_p.to_sym
      kind_p  &&= kind_p  != '*' && kind_p.to_sym
      owner_p &&= owner_p != '*' && owner_p

      methods = [ ]
      seen = { }
      ObjectSpace.each_object(::Module) do | owner |
        next unless (owner.name rescue nil)
        next if owner_p && owner_p != owner.name

        kind = :instance_method
        owner.instance_methods(false).each do | name |
          next if name_p && name_p != (name = name.to_sym)
          next if kind_p && kind_p != kind
          if meth = (owner.instance_method(name) rescue nil) and key = [ owner, kind, name ] and ! seen[key]
            seen[key] = true
            methods << MockMethod.new(meth, name, kind, owner)
          end
        end

        kind = :method
        owner.singleton_methods(false).each do | name |
          next if name_p && name_p != (name = name.to_sym)
          next if kind_p && kind_p != kind
          if meth = (owner.singleton_method(name) rescue nil) and key = [ owner, kind, name ] and ! seen[key]
            seen[key] = true
            methods << MockMethod.new(meth, name, kind, owner)
          end
        end
      end
      methods.sort_by!{|x| x.owner.to_s}
      methods
    end

    class MockMethod
      attr_accessor :meth, :name, :kind, :owner
      def initialize *args
        @meth, @name, @kind, @owner = args
      end
      def source_location
        @meth.source_location
      end
    end

    def file_line_to_href name, lineno = nil
      link = name.sub(%r{^/}, '-')
      link = link.split('/').map{|s| e s}.join('/')
      link = url_root("/file/#{link}")
      link << ":#{lineno}\##{lineno - 2}" if lineno
      link
    end

    def href_to_file_line path
      path.to_s =~ /^([^:]+)(:([^:]+))?/
      file, line = $1, $3
      file.sub!(/^-/, '/')
      [ file, line && line.to_i ]
    end

    def source_file source_location
      source_location && SourceFile.new(source_location).load!
    end

    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def e(text)
      Rack::Utils.escape(text.to_s)
    end

    def limit_string(text, len)
      text = text.to_s
      if text.size > len
        text = text[0 .. len] + ' ...'
      end
      text
    end

    def format_module obj
      return module_name_tag(h(obj.inspect)) unless obj && obj.name
      path = obj.name.to_s.split('::')
      result = ''
      name = ''; pre = ''
      path.each do | n |
        name << n
        href = url_root("/module/#{name}")
        result << "<a href='#{href}' class='module_name'>#{module_name_tag("#{pre}#{h n}")}</a>"
        name << '::'
        pre = '::'
      end
      module_name_tag(result)
    end

    def format_method m, kind, owner = nil
      owner ||= m.owner
      source_location = m.source_location
      source_location &&= source_location * ":"
      href = url_root("/method/#{owner.name}/#{e kind.to_s}/#{e m.name}")
      "<a href='#{href}' title='#{source_location}' class='method_name'>#{method_name_tag(h(m.name))}</a>"
    end

    def format_methods name
      href = url_root("/methods/*/*/#{e name}")
      "<a href='#{href}' title='Other methods named #{h name.inspect}' class='method_name'>#{method_name_tag(h(name))}</a>"
    end

    def file_name_tag str
      %Q{<span class="file_name">#{str}</span>}
    end

    def module_name_tag str
      %Q{<span class="module_name">#{str}</span>}
    end

    def method_name_tag str
      %Q{<span class="method_name">#{str}</span>}
    end

    def literal_tag str
      %Q{<span class="literal">#{str}</span>}
    end

    def format_backtrace line
      line = line.to_s
      html =
        if line =~ /^(.*):(\d+):(in .*)$/ && File.exist?($1)
          "#{format_source_location([$1, $2.to_i])}:#{h $3}"
        else
          file_name_tag(h line)
        end
      %Q{<span class="backtrace">#{html}</span>}
    end

    def safe_format obj
      begin
        ::PP.pp(obj, '')
      rescue
        obj.inspect
      end
    end
  end
end

require 'active_support/core_ext/class/subclasses'
require 'active_support/core_ext/object/blank'
require 'pp'
require 'stringio'
require 'rack_console/ansi2html'

module RackConsole
  module AppHelpers
    def has_console_access?
      true
    end

    def has_file_access? file
      ! ! (file != '(eval)' && $".include?(file))
    end

    def url_root url
      "#{config[:url_root_prefix]}#{url}"
    end

    def locals
      @locals ||= { }
    end

    def layout
      config[:layout] || :layout
    end

    def find_template(views, name, engine, &block)
      views = config[:views] || views
      Array(views).each do |v|
        v = config[:views_default] if v == :default
        super(v, name, engine, &block)
      end
    end

    def css_dir
      config[:css_dir]
    end

    ###############################

    def console!
      if has_console_access?
        haml :console, locals: locals, layout: layout
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
          @constants = @module.constants(false).sort.map{|n| [ n, const_get_safe(@module, n) ]}
          @methods = methods_for_module(@module)
        end
      end
    end

    def evaluate_method!
      evaluate_expr!
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

    def format_object obj, inline = false
      case obj
      when Module
        format_module obj
      else
        format_other obj, inline
      end
    end

    def format_other obj, inline = false
      if inline
        literal_tag(h(limit_string(safe_format(obj), 80)))
      else
        safe_format_structured(obj)
      end
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
          kind ||= (owner.instance_method(name) rescue nil) ? :i : :c
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
      name_p  = match_pred(params[:name], :to_sym)
      kind_p  = match_pred(params[:kind], :to_sym)
      owner_p = match_pred(params[:owner])

      methods = [ ]
      seen = { }
      ObjectSpace.each_object(::Module) do | owner |
        next unless (owner.name rescue nil)
        next if owner_p && owner_p != owner.name
        methods_for_module(owner, name_p, kind_p, seen, methods)
      end
      sort_methods! methods
      methods
    end

    def match_pred value, m = nil
      if value != '*' && value != ''
        value = value.send(m) if m
      else
        value = nil
      end
      value
    end

    def methods_for_module owner, name_p = nil, kind_p = nil, seen = { }, to_methods = nil
      methods = to_methods || [ ]
      kind = :i
      unless kind_p && kind_p != kind
        instance_method_names(owner).each do | name |
          next if name_p && name_p != (name = name.to_sym)
          if meth = (owner.instance_method(name) rescue nil) and key = [ owner, kind, name ] and ! seen[key]
            seen[key] = true
            methods << MockMethod.new(meth, name, kind, owner)
          end
        end
      end

      kind = :c
      unless kind_p && kind_p != kind
        singleton_method_names(owner).each do | name |
          next if name_p && name_p != (name = name.to_sym)
          if meth = (owner.singleton_method(name) rescue nil) and key = [ owner, kind, name ] and ! seen[key]
            seen[key] = true
            methods << MockMethod.new(meth, name, kind, owner)
          end
        end
      end
      sort_methods! methods unless to_methods
      methods
    end

    def sort_methods! methods
      methods.sort_by!{|x| [ x.owner.to_s, x.kind, x.name ]}
    end

    def instance_method_names owner
      ( owner.instance_methods(false) |
        owner.private_instance_methods(false) |
        owner.protected_instance_methods(false)
        ).sort
    end

    def singleton_method_names owner
      owner.singleton_methods(false)
    end

    class MockMethod
      attr_accessor :meth, :name, :kind, :owner
      def initialize *args
        @meth, @name, @kind, @owner = args
      end
      def instance_method?
        @kind == :i
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
      href = method_href(m, kind, owner)
      "<a href='#{href}' title='#{source_location}' class='method_name'>#{method_name_tag(h(m.name))}</a>"
    end

    def method_href m, kind, owner = nil
      owner ||= m.owner
      href = url_root("/method/#{owner.name}/#{e kind.to_s}/#{e m.name}")
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

    def wrap_lines str, width = 80
      str.to_s.split("\n").map do | line |
        wrap_line line, width
      end * "\n"
    end

    def wrap_line str, width = 80
      str = str.to_s
      out = ''
      pos = 0
      while pos < str.size
        out << h(str[pos, width])
        pos += width
        out << "&nbsp;\u21B5\n" if pos < str.size
      end
      out
    end

    def safe_format_structured obj
      begin
        if config[:awesome_print] && defined?(::AwesomePrint)
          ansi = obj.ai(indent: 2, html: false, index: false)
          ansi2html(ansi)
        else
          '<pre>' << wrap_lines(safe_pp(obj)) << '</pre>'
        end
      rescue
        STDERR.puts "  #{$!.inspect}: falling back to #inspect for #{obj.class}\n  #{$!.backtrace * "\n  "}"
        '<pre>' << wrap_lines(obj.inspect) << '</pre>'
      end
    end

    def safe_format obj
      safe_pp(obj)
    end

    def safe_pp obj
      ::PP.pp(obj, '')
    rescue
      STDERR.puts "  #{$!.inspect}: falling back to #inspect for #{obj.class}\n  #{$!.backtrace * "\n  "}"
      obj.inspect
    end

    def ansi2html ansi
      Ansi2Html.new.convert(ansi, '')
    end
  end
end

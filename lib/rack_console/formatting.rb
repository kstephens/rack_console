# encoding: UTF-8
require 'time'
require 'date'
require 'pp'
require 'rack_console/ansi2html'

module RackConsole
  module Formatting
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
        literal_tag(h(limit_string(safe_format(obj).strip, 80)))
      else
        safe_format_structured(obj)
      end
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

    def source_file_methods_href file
      link = file.sub(%r{^/}, '-')
      link = url_root("/methods/file/#{link}")
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

    def format_constant_name mod, name
      href = constant_name_href(mod, name)
      "<a href='#{href}' class='constant_name'>#{constant_name_tag(name)}</a>"
    end

    def format_method m, kind, owner = nil
      owner ||= m.owner
      source_location = m.source_location
      source_location &&= source_location * ":"
      href = method_href(m, kind, owner)
      "<a href='#{href}' title='#{source_location}' class='method_name'>#{method_name_tag(h(m.name))}</a>"
    end

    def constant_name_href mod, name
      mod_path = "::#{mod.name}::#{name}"
      url_root("/?expr=#{mod_path}")
    end

    def method_href m, kind, owner = nil
      owner ||= m.owner
      url_root("/method/#{owner.name}/#{e kind.to_s}/#{e m.name}")
    end

    def format_methods obj
      case obj
      when nil
        return nil
      when ::Method, ::UnboundMethod, MockMethod
        name = obj.name or return nil
      else
        name = obj.to_s
      end
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

    def constant_name_tag str
      %Q{<span class="constant_name">#{str}</span>}
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

    def wrap_lines str, width = nil
      str.to_s.split("\n").map do | line |
        wrap_line line, width
      end * "\n"
    end

    def wrap_line str, width = nil
      width ||= config[:wrap_width] || 80
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

    def format_as_terminal str
      str &&= str.to_s.force_encoding('UTF-8')
      if str.blank?
        %Q{<span class="none">NONE</span>}
      else
        ansi2html(str)
      end
    end

    def ansi2html ansi
      Ansi2Html.new.convert(ansi, '')
    end
  end
end


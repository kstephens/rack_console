require 'time'
require 'date'
require 'rack_console/mock_method'

module RackConsole
  module Configuration
    def has_console_access?
      case a = config[:authorized?]
      when true, false
        a
      when Proc
        a.call
      else
        true
      end
    end

    def check_access!
      unauthorized! unless has_console_access?
    end

    def unauthorized!
      raise Error, "not authorized"
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

    def eval_target
      case et = config[:eval_target]
      when Proc
        et.call
      else
        et
      end
    end

    def server_info
      thr = Thread.current
      (config[:server_info] || { }).merge(
        host: Socket.gethostname,
        pid: Process.pid,
        ppid: Process.ppid,
        thread: thr[:name] || thr.object_id,
        ruby_engine: (RUBY_ENGINE rescue :UNKNOWN),
        ruby_version: RUBY_VERSION,
        rack_console_version: "v#{VERSION}",
      )
    end
  end
end


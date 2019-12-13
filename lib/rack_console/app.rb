require 'rack_console'
require 'rack_console/source_file'
require 'rack_console/app_helpers'
require 'sinatra'
require 'tilt/haml'
require 'haml'
require 'logger'

module RackConsole
  class App < Sinatra::Application
    set :views, :default

    before do
      check_access! unless request.path_info =~ %r{^/(css/|js/|favicon.ico$)}
    end

    get '/?' do
      console!
    end

    post '/?' do
      console!
    end

    get "/module/:expr" do
      evaluate_module!
      haml :'console/module', locals: locals, layout: layout
    end

    get "/method/:expr/:kind/:name" do
      evaluate_method!
      haml :'console/method', locals: locals, layout: layout
    end

    get "/methods/:owner/:kind/:name" do
      evaluate_methods!
      haml :'console/methods', locals: locals, layout: layout
    end

    get "/file/*" do
      prepare_file!
      haml :'console/file', locals: locals, layout: layout
    end

    get "/methods/file/*" do
      prepare_file!
      @methods = methods_within_file(@source_file.file) if @source_file
      haml :'console/methods', locals: locals, layout: layout
    end

    get "/css/:path" do | path |
      file! 'text/css', css_dir, path
    end

    get "/js/:path" do | path |
      file! 'text/javascript', js_dir, path
    end

    get "/favicon.ico" do
      content_type 'text/plain'
      ''
    end

    helpers do
      include AppHelpers
      def file! ct, dir, path
        halt 404 if path =~ /\.\./
        path = "#{dir}/#{path}"
        halt 404 unless File.file?(path)
        content_type ct
        send_file path
      end
    end

    def initialize config = nil
      @config = config || { }
      @config[:views_default]  ||= "#{File.expand_path('..', __FILE__)}/template/haml"
      @config[:css_dir]        ||= "#{File.expand_path('..', __FILE__)}/template/css"
      @config[:js_dir]         ||= "#{File.expand_path('..', __FILE__)}/template/js"
      @logger = @config[:logger] || ::Logger.new($stderr)
      super
    end
    attr_accessor :config, :logger
  end
end

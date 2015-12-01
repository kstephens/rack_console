require 'rack_console/source_file'
require 'rack_console/app_helpers'
require 'sinatra'
require 'tilt/haml'
require 'haml'

module RackConsole
  class App < Sinatra::Application
    set :views, :default

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
      halt 404 if path =~ /\.\./
      content_type 'text/css'
      send_file "#{css_dir}/#{path}"
    end

    helpers do
      include AppHelpers
    end

    def initialize config = { }
      @config = config
      @config[:views_default] ||= "#{File.expand_path('..', __FILE__)}/template/haml"
      @config[:css_dir] ||= "#{File.expand_path('..', __FILE__)}/template/css"
      super
    end
    attr_accessor :config
  end
end

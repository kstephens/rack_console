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

    helpers do
      include AppHelpers
    end

    def initialize config = { }
      @config = config
      @config[:views_default] ||= "#{File.expand_path('..', __FILE__)}/template/haml"
      super
    end
    attr_accessor :config
  end
end

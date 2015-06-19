require 'rack_console/source_file'
require 'rack_console/app_helpers'
require 'sinatra'
require 'tilt/haml'
require 'haml'

module RackConsole
  class App < Sinatra::Application
    set :views, "#{File.expand_path('..', __FILE__)}/template/haml"

    get '/?' do
      console!
    end

    post '/?' do
      console!
    end

    get "/module/:expr" do
      evaluate_module!
      haml :'console/module', locals: locals
    end

    get "/method/:expr/:kind/:name" do
      evaluate_method!
      haml :'console/method', locals: locals
    end

    get "/methods/:owner/:kind/:name" do
      evaluate_methods!
      haml :'console/methods', locals: locals
    end

    get "/file/*" do
      prepare_file!
      haml :'console/file', locals: locals
    end

    helpers do
      include AppHelpers
    end

    def initialize config = { }
      @config = config
      super
    end
    attr_accessor :config
  end
end

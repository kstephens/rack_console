require 'sinatra'
require 'tilt/haml'
require 'haml'
gem 'awesome_print'; require 'ap'

module EX01
  AnonModule = Module.new
  GiantArray = (0 .. 10000).to_a.freeze
end

class App < Sinatra::Application
  include RackConsole::Configuration
  set :views, "#{File.expand_path('..', __FILE__)}/template/haml"
  get '/?' do
    haml :'index'
  end

  helpers do
    def config
      { }
    end
  end
end


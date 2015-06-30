require 'sinatra'
require 'tilt/haml'
require 'haml'
gem 'awesome_print'; require 'ap'

class App < Sinatra::Application
  set :views, "#{File.expand_path('..', __FILE__)}/template/haml"

  get '/?' do
    haml :'index'
  end
end


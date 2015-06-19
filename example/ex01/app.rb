require 'sinatra'
require 'tilt/haml'
require 'haml'

class App < Sinatra::Application
  set :views, "#{File.expand_path('..', __FILE__)}/template/haml"

  get '/?' do
    haml :'index'
  end
end


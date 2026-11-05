# frozen_string_literal: true

require 'sinatra'
require 'tilt/haml'
require 'haml'
gem 'awesome_print'; require 'ap'

AwesomePrint.defaults = {
  color: {
    args:       :pale,       # Soft contrast
    array:      :white,      # Clear array structure
    class:      :yellow,     # Standard class color
    date:       :greenish,   # Soft muted green
    falseclass: :red,        # Visible red
    hash:       :pale,       # Soft contrast
    keyword:    :cyan,       # Pops against dark backgrounds
    method:     :purpleish,  # Muted purple for readability
    string:     :yellowish,  # Warm, eye-friendly yellow
    trueclass:  :green,      # Bright green
    variable:   :cyanish     # Muted cyan for variables
  }
}

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


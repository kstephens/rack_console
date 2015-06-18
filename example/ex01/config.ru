$:.unshift "../../lib"
require 'rack_console/app'
require 'pry'
use Rack::Reloader
use Rack::Static, :urls => ["/css", "/img"], :root => "public"
run RackConsole::App


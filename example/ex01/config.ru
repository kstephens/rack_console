$:.unshift "../../lib"
$:.unshift "."
require 'rack_console/app'
require 'pry'
require 'app'
use Rack::Reloader
use Rack::Static, :urls => ["/css", "/img"], :root => "public"
run Rack::URLMap.new(
  "/console" => RackConsole::App.new(url_root_prefix: "/console")
  "/"        => App.new,
  )


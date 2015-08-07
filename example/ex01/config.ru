$:.unshift "../../lib"
$:.unshift "."
require 'rack_console/app'
require 'app'
use Rack::Reloader
run Rack::URLMap.new(
  "/console" => RackConsole::App.new(
    awesome_print: true,
    url_root_prefix: "/console",
    views: [ 'template/haml', :default ]),
  "/"        => App.new
  )


# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack_console/version'

Gem::Specification.new do |spec|
  spec.name          = "rack_console"
  spec.version       = RackConsole::VERSION
  spec.authors       = ["Kurt Stephens"]
  spec.email         = ["ks.github@kurtstephens.com"]

  spec.summary       = %q{A Rack App that provides a basic interactive Ruby console and introspection.}
  spec.description   = %q{A Rack App that provides a basic interactive Ruby console and introspection.}
  spec.homepage      = "https://github.com/kstephens/rack_console"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sinatra", "~> 1.4"
  spec.add_dependency "haml", "~> 4.0"
  spec.add_dependency "activesupport", ">= 3.0"
  spec.add_dependency "awesome_print", "~> 1.6"

  spec.add_development_dependency "bundler", "~> 1.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.3"
  spec.add_development_dependency "guard", "~> 2.12"
  spec.add_development_dependency "guard-rspec", "~> 4.5"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "simplecov", "~> 0.11"
end

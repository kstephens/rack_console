require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :coverage => [ :enable_coverage, :spec ]
task :enable_coverage do
  ENV['COVERAGE'] = "1"
end

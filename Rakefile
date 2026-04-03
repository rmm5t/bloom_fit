require "bundler/gem_tasks"
require "bundler/setup"
require "rspec/core/rake_task"
require "rake/extensiontask"

Rake::ExtensionTask.new("cbloomfilter")
RSpec::Core::RakeTask.new(:spec)
Rake::Task[:spec].prerequisites << :clean
Rake::Task[:spec].prerequisites << :compile

desc "Default: run unit tests."
task default: :spec

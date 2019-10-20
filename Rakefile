require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new('rubocop', '--config',  File.join(File.dirname(__FILE__), '.rubocop.yml') )

task default: :build

task :build => [:rubocop, :spec]

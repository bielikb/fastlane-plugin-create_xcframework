require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop)

desc 'Run Fasterer'
task :fasterer do
  sh('bundle exec fasterer')
end

task(default: [:rubocop, :fasterer, :spec])

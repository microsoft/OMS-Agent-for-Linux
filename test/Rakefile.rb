#!/usr/local/ruby-2.2.0/bin rake

require 'rake/testtask'
require 'rake/clean'

task :test => [:base_test]

desc 'Run test_unit based test'
Rake::TestTask.new(:base_test) do |t|
  plugin_test_files = Dir["#{ENV['PLUGINS_TEST_DIR']}/*_test.rb"].sort
  script_test_files = Dir["#{ENV['BASE_DIR']}/test/installer/scripts/*_test.rb"].sort
  t.test_files = plugin_test_files + script_test_files
  t.verbose = true
  t.warning = true
end

desc 'Run test_unit based test'
Rake::TestTask.new(:systemtest) do |t|
  t.libs << '/home/niroy/dev/work/omsagent/source/ext/fluentd/lib/'
  t.test_files = Dir["#{ENV['PLUGINS_TEST_DIR']}/*_systest.rb"].sort
  t.verbose = true
  # t.warning = true
end

desc 'Run test with simplecov'
task :coverage do |t|
  ENV['SIMPLE_COV'] = '1'
  Rake::Task["test"].invoke
end

task :default => [:test, :build]

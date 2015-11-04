#!/usr/local/ruby-2.2.0/bin rake

require 'rake/testtask'
require 'rake/clean'

task :test => [:base_test]

desc 'Run test_unit based test'
Rake::TestTask.new(:base_test) do |t|
  t.test_files = Dir["#{ENV['BASE_DIR']}/test/**/*_test.rb"].sort
  t.verbose = true
  t.warning = true
end

desc 'Run test_unit based system tests'
Rake::TestTask.new(:systemtest) do |t|
  t.libs << '/home/niroy/dev/work/omsagent/source/ext/fluentd/lib/'
  t.test_files = Dir["#{ENV['BASE_DIR']}/test/**/*_systest.rb"].sort
  t.verbose = true
  # t.warning = true
end

desc 'Run test with simplecov'
task :coverage do |t|
  ENV['SIMPLE_COV'] = '1'
  Rake::Task["test"].invoke
end

task :default => [:test, :build]

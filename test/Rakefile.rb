#!/usr/local/ruby-2.2.0/bin rake

require 'rake/testtask'
require 'rake/clean'

task :test => [:prerequisites, :base_test, :plugintest]
desc 'check for gem dependencies and install any missing gems'
Rake::TestTask.new(:prerequisites) do
  required_gems = %w{
                     mocha
                     }
 
  gem_list = %x{#{ENV['RUBY_DEST_DIR']}/bin/gem list}
 
  # check gem sources and only add github if its not already there
  if ((%x{#{ENV['RUBY_DEST_DIR']}/bin/gem sources} =~ %r{https://rubygems.org})).nil?
    puts %x{sudo #{ENV['RUBY_DEST_DIR']}/bin/gem sources -a https://rubygems.org}
  end
 
  required_gems.each do | gem_name |
    if (gem_list=~ %r{#{gem_name}}).nil?
      puts %x{sudo #{ENV['RUBY_DEST_DIR']}/bin/gem install #{gem_name}}
    end
  end
end


desc 'Run test_unit based test'
Rake::TestTask.new(:base_test) do |t|
  t.test_files = Dir["#{ENV['BASE_DIR']}/test/**/*_test.rb"].sort
  t.verbose = true
  t.warning = true
end

desc 'Run test_unit based test'
Rake::TestTask.new(:base_test) do |t|
  t.test_files = Dir["#{ENV['BASE_DIR']}/test/**/*_test.rb"].sort
  t.verbose = true
  t.warning = true
end

desc 'Run test_unit based plugin tests'
Rake::TestTask.new(:plugintest) do |t|
  t.test_files = Dir["#{ENV['BASE_DIR']}/test/**/*_plugintest.rb"].sort
  t.verbose = true
  #t.warning = true
end

desc 'Run test_unit based system tests'
Rake::TestTask.new(:systemtest) do |t|
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

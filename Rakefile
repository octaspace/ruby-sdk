# frozen_string_literal: true

begin
  require "bundler/setup"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

requested_tasks = Rake.application.top_level_tasks

if (requested_tasks & %w[rdoc clobber_rdoc]).any?
  require "rdoc/task"

  RDoc::Task.new(:rdoc) do |rdoc|
    rdoc.rdoc_dir = "rdoc"
    rdoc.title = "OctaSpace Ruby SDK"
    rdoc.options << "--line-numbers"
    rdoc.rdoc_files.include("README.md")
    rdoc.rdoc_files.include("lib/**/*.rb")
  end
end

if (requested_tasks & %w[build install]).any?
  require "bundler/gem_tasks"
end

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
end

if (requested_tasks & %w[lint standard standard:fix standard:fix_unsafely]).any?
  require "standard/rake"

  desc "Lint with the Standard Ruby style guide"
  task lint: :standard
end

if defined?(Rails)
  load "rails/tasks/statistics.rake"
  STATS_DIRECTORIES = [
    %w[Library lib/],
    %w[Tests test/]
  ].freeze
end

task default: :test

# frozen_string_literal: true

require "rake/testtask"
require "standard/rake"

Rake::TestTask.new(:test) do |t|
  t.libs    << "test"
  t.libs    << "lib"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
end

task default: %i[standard test]

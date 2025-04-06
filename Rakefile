require "bundler/gem_tasks"
require "rake/testtask"

# Standard test task
desc "Run tests"
Rake::TestTask.new(:test) do |t|
  t.libs << "tests"
  t.libs << "lib"
  t.test_files = FileList["tests/**/*_test.rb"]
end

# Verbose test task 
desc "Run tests with verbose output"
Rake::TestTask.new(:test_verbose) do |t|
  t.libs << "tests"
  t.libs << "lib"
  t.test_files = FileList["tests/**/*_test.rb"]
  t.verbose = true
  t.warning = true
end

# Performance tests only
desc "Run only performance tests"
Rake::TestTask.new(:test_performance) do |t|
  t.libs << "tests"
  t.libs << "lib"
  t.test_files = FileList["tests/performance_test.rb"]
  t.verbose = true
end

# Unit tests only (excluding performance tests)
desc "Run unit tests (excluding performance tests)"
Rake::TestTask.new(:test_unit) do |t|
  t.libs << "tests"
  t.libs << "lib"
  t.test_files = FileList["tests/**/*_test.rb"] - FileList["tests/performance_test.rb"]
end

# Individual component tests
%w[config git templates hooks].each do |component|
  desc "Run #{component} tests"
  Rake::TestTask.new("test_#{component}") do |t|
    t.libs << "tests"
    t.libs << "lib"
    t.test_files = FileList["tests/#{component}_test.rb"]
  end
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
  task default: %i[test rubocop]
rescue LoadError
  task default: %i[test]
end

desc "Run all tests and checks"
task :ci => [:test_unit, :test_performance, :rubocop] 
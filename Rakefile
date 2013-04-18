desc 'Runs the test suite'
task :test do
  sh 'rm -rf coverage'
  sh "bacon test/json-rpc-test.rb"
end

desc "Run tests"
task :default => :test

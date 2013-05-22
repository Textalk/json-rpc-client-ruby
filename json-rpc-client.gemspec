require 'rake'

Gem::Specification.new do |s|
  s.name                  = 'json-rpc-client'
  s.homepage              = 'https://github.com/Textalk/json-rpc-client-ruby'
  s.license               = 'MIT'
  s.authors               = ["Fredrik Liljegren", "Lars Olsson", "Denis Dervisevic"]
  s.version               = '0.1.1'
  s.date                  = '2013-04-18'
  s.summary               = "JSON-RPC 2.0 client."
  s.description           = "Asynchronous (EventMachine) JSON-RPC 2.0 over HTTP client."
  s.files                 = FileList['lib/**/*.rb', '[A-Z]*', 'test/**/*.rb'].to_a
  s.platform              = Gem::Platform::RUBY
  s.require_path          = "lib"
  s.required_ruby_version = '>= 1.9.0'

  s.add_dependency('addressable')
  s.add_dependency('em-http-request')
  s.add_dependency('json')

  s.add_development_dependency('bacon')
  s.add_development_dependency('em-spec')
  s.add_development_dependency('rack')
  s.add_development_dependency('rake')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('simplecov-rcov')
  s.add_development_dependency('vcr')
  s.add_development_dependency('webmock', '=1.9.0')
end

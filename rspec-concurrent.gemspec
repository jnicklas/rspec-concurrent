# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rspec/concurrent/version'

Gem::Specification.new do |spec|
  spec.name          = "rspec-concurrent"
  spec.version       = Rspec::Concurrent::VERSION
  spec.authors       = ["Ivan Navarrete and Jonas Nicklas"]
  spec.email         = ["dev+ivannavarrete+jnicklas@elabs.se"]
  spec.description   = %q{Run RSpec concurrently with Celluloid}
  spec.summary       = %q{Run RSpec concurrently with Celluloid}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec", "~> 2.0"
  spec.add_dependency "celluloid"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end

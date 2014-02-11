# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stompede/version'

Gem::Specification.new do |spec|
  spec.name          = "stompede"
  spec.version       = Stompede::VERSION
  spec.authors       = ["Kim Burgestrand", "Jonas Nicklas"]
  spec.email         = ["kim@burgestrand.se", "jonas.nicklas@gmail.com"]
  spec.summary       = %q{STOMP over WebSockets.}
  spec.homepage      = "https://github.com/stompede/stompede"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "reel"
  spec.add_dependency "celluloid"
  spec.add_dependency "celluloid-io"
  spec.add_dependency "stomp_parser"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rake-compiler"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end

# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/create_xcframework/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-create_xcframework'
  spec.version       = Fastlane::CreateXcframework::VERSION
  spec.summary       = "Fastlane plugin that creates xcframework for given list of destinations."
  spec.description   = "Fastlane plugin that creates xcframework for given list of destinations."
  spec.homepage      = "https://github.com/bielikb/fastlane-plugin-create_xcframework"
  spec.license       = "MIT"
  spec.authors       = ["Boris Bielik", "Alexey Alter-Pesotskiy"]
  spec.email         = ["bielik.boris@gmail.com", "a.alterpesotskiy@mail.ru"]

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.bindir        = "bin"
  spec.require_paths = ['lib']

  spec.add_development_dependency('pry')
  spec.add_development_dependency('bundler')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('fasterer', '0.8.3')
  spec.add_development_dependency('rubocop', '0.49.1')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('simplecov')
  spec.add_development_dependency('fastlane', '>= 2.144.0')
end

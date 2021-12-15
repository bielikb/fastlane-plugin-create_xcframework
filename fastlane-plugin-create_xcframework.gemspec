lib = File.expand_path("lib", __dir__)
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
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.4'
  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fasterer', '0.9.0')
  spec.add_development_dependency('fastlane', '>= 2.182.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '1.12.1')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-rake', '0.6.0')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('rubocop-rspec', '2.4.0')
  spec.add_development_dependency('simplecov')
end

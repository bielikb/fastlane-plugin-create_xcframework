$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

# SimpleCov.minimum_coverage 95
SimpleCov.start

# Allow message expectations on nil
RSpec.configure do |config|
  config.mock_with(:rspec) do |mocks|
    mocks.allow_message_expectations_on_nil = true
  end
end

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/create_xcframework' # import the actual plugin

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)

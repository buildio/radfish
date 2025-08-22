require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
end

require 'bundler/setup'
require 'radfish'
require 'webmock/rspec'
require 'vcr'

# Load support files
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  # Filter sensitive data
  config.filter_sensitive_data('<BMC_HOST>') { ENV['BMC_HOST'] }
  config.filter_sensitive_data('<BMC_USERNAME>') { ENV['BMC_USERNAME'] }
  config.filter_sensitive_data('<BMC_PASSWORD>') { ENV['BMC_PASSWORD'] }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching :focus
  config.order = :random
  Kernel.srand config.seed
  
  # Include test helpers
  config.include RadfishSpecHelpers if defined?(RadfishSpecHelpers)
  config.include Factories if defined?(Factories)
end
# frozen_string_literal: true

# Load the shared examples for adapter compliance testing.
#
# Usage in your adapter gem's spec_helper.rb:
#
#   require 'radfish/spec/adapter_compliance'
#
# Then in your adapter spec:
#
#   RSpec.describe Radfish::MyAdapter do
#     let(:adapter) do
#       described_class.new(
#         host: "bmc.example.com",
#         username: "admin",
#         password: "password"
#       )
#     end
#
#     # Test that all required methods exist
#     it_behaves_like "a radfish adapter"
#
#     # Test with mocked/live connection (requires stubs or real BMC)
#     context "with connection" do
#       before { allow(adapter).to receive(:login).and_return(true) }
#       it_behaves_like "a connected radfish adapter"
#     end
#   end

require 'rspec'

# Load the shared examples
spec_path = File.expand_path('../../../spec/support/shared_examples/adapter_compliance.rb', __dir__)
require spec_path if File.exist?(spec_path)

# If running from installed gem, define inline
unless RSpec.world.shared_example_group_registry.find([:main], "a radfish adapter")
  require_relative 'adapter_compliance/shared_examples'
end

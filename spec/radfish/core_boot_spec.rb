# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Radfish::Core::Boot do
  # A bare includer of the module, so we exercise the concrete default rather than an adapter
  # override.
  let(:includer_class) do
    Class.new do
      include Radfish::Core::Boot
    end
  end
  let(:adapter) { includer_class.new }

  describe "#set_one_time_cd_boot" do
    it "delegates to boot_to_cd by default" do
      expect(adapter).to receive(:boot_to_cd)
      adapter.set_one_time_cd_boot
    end

    it "accepts reboot: for signature parity and still delegates to boot_to_cd" do
      expect(adapter).to receive(:boot_to_cd)
      adapter.set_one_time_cd_boot(reboot: false)
    end
  end
end

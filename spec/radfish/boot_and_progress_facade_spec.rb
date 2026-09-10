# frozen_string_literal: true

require 'spec_helper'

# The vendor-neutral facade the app calls through Radfish::Client, replacing the raw-Redfish and
# adapter reach-through it used to hand-roll.
RSpec.describe Radfish::Client, "boot/power facade" do
  let(:adapter) { double('adapter') }
  let(:client) do
    c = described_class.allocate
    c.instance_variable_set(:@adapter, adapter)
    c.instance_variable_set(:@vendor, 'mock')
    c
  end

  describe "#power_state" do
    it "returns the adapter's live power status" do
      allow(adapter).to receive(:power_status).and_return("On")
      expect(client.power_state).to eq("On")
    end
  end

  describe "#boot" do
    it "returns a BootInfo facade" do
      expect(client.boot).to be_a(Radfish::BootInfo)
    end

    describe "BootInfo#stale_uefi_entries" do
      it "delegates to the adapter" do
        allow(adapter).to receive(:stale_uefi_boot_entries).and_return([{ "Name" => "Unknown.Unknown.1-1" }])
        expect(client.boot.stale_uefi_entries.first["Name"]).to eq("Unknown.Unknown.1-1")
      end
    end

    describe "BootInfo#disable_entries" do
      it "delegates with the adapter default when no match is given" do
        expect(adapter).to receive(:disable_boot_entries).with(no_args).and_return(["Unknown.Unknown.1-1"])
        expect(client.boot.disable_entries).to eq(["Unknown.Unknown.1-1"])
      end

      it "passes a match through" do
        expect(adapter).to receive(:disable_boot_entries).with(match: /Optical/).and_return(["Optical.iDRACVirtual.1-1"])
        expect(client.boot.disable_entries(match: /Optical/)).to eq(["Optical.iDRACVirtual.1-1"])
      end
    end

    it "raises NotImplementedError when the adapter cannot disable entries" do
      allow(adapter).to receive(:respond_to?).with(:disable_boot_entries).and_return(false)
      expect { client.boot.disable_entries }.to raise_error(NotImplementedError, /does not support/)
    end

    describe "BootInfo#set_one_time_cd_boot" do
      it "delegates to the adapter, passing options through" do
        allow(adapter).to receive(:respond_to?).with(:set_one_time_cd_boot).and_return(true)
        expect(adapter).to receive(:set_one_time_cd_boot).with(reboot: false).and_return(status: :success)
        expect(client.boot.set_one_time_cd_boot(reboot: false)).to eq(status: :success)
      end

      it "raises NotImplementedError on an adapter with no SCP one-time-boot path" do
        allow(adapter).to receive(:respond_to?).with(:set_one_time_cd_boot).and_return(false)
        expect { client.boot.set_one_time_cd_boot }.to raise_error(NotImplementedError, /does not support/)
      end
    end

    describe "BootInfo#wait_config_job" do
      it "delegates the job id and options to the adapter" do
        allow(adapter).to receive(:respond_to?).with(:wait_config_job).and_return(true)
        expect(adapter).to receive(:wait_config_job).with("JID_5", timeout: 30).and_return("Completed")
        expect(client.boot.wait_config_job("JID_5", timeout: 30)).to eq("Completed")
      end
    end

    describe "BootInfo#drain_config_jobs" do
      it "delegates to the adapter's LC068 drain" do
        allow(adapter).to receive(:respond_to?).with(:drain_pending_config_jobs!).and_return(true)
        expect(adapter).to receive(:drain_pending_config_jobs!).and_return(["JID_1"])
        expect(client.boot.drain_config_jobs).to eq(["JID_1"])
      end
    end
  end

  describe "#boot_progress" do
    it "returns the adapter's normalized state" do
      allow(adapter).to receive(:respond_to?).with(:boot_progress).and_return(true)
      allow(adapter).to receive(:boot_progress).and_return(:os_running)
      expect(client.boot_progress).to eq(:os_running)
    end

    it "returns nil when the adapter has no boot_progress" do
      allow(adapter).to receive(:respond_to?).with(:boot_progress).and_return(false)
      expect(client.boot_progress).to be_nil
    end
  end

  describe "#wait_for_boot_progress" do
    before do
      allow(adapter).to receive(:respond_to?).with(:boot_progress).and_return(true)
      allow(adapter).to receive(:respond_to?).with(:boot_progress_ceiling).and_return(true)
    end

    it "returns the state once the target is reached" do
      allow(adapter).to receive(:boot_progress_ceiling).and_return(600)
      allow(adapter).to receive(:boot_progress).and_return(:os_running)
      expect(client.wait_for_boot_progress(:os_running)).to eq(:os_running)
    end

    it "returns immediately with nil when the BMC omits BootProgress (iDRAC8)" do
      allow(adapter).to receive(:boot_progress_ceiling).and_return(600)
      allow(adapter).to receive(:boot_progress).and_return(nil)
      expect(client.wait_for_boot_progress(:os_running)).to be_nil
    end

    it "treats a later state as having passed the target" do
      allow(adapter).to receive(:boot_progress_ceiling).and_return(600)
      allow(adapter).to receive(:boot_progress).and_return(:os_running)
      expect(client.wait_for_boot_progress(:setup_entered)).to eq(:os_running)
    end

    it "raises BootProgressTimeout on a stall, using the adapter's per-model ceiling" do
      # A zero ceiling makes the deadline trip on the first non-matching read (no real wait), and
      # proves wait_for_boot_progress consults the adapter's ceiling when no timeout is passed.
      expect(adapter).to receive(:boot_progress_ceiling).with(:os_running).and_return(0)
      allow(adapter).to receive(:boot_progress).and_return(:setup_entered)
      allow(client).to receive(:sleep)
      expect { client.wait_for_boot_progress(:os_running) }
        .to raise_error(Radfish::BootProgressTimeout, /did not reach :os_running/)
    end
  end
end

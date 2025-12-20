# frozen_string_literal: true

# Shared examples for testing adapter compliance with the Radfish interface.
#
# Usage in your adapter gem's spec:
#
#   require 'radfish/spec/adapter_compliance'
#
#   RSpec.describe MyAdapter do
#     let(:adapter) do
#       described_class.new(
#         host: "bmc.example.com",
#         username: "admin",
#         password: "password"
#       )
#     end
#
#     it_behaves_like "a radfish adapter"
#   end

RSpec.shared_examples "a radfish adapter" do
  # Core requirements
  describe "adapter interface" do
    it "responds to vendor" do
      expect(adapter).to respond_to(:vendor)
    end

    it "returns a string vendor name" do
      expect(adapter.vendor).to be_a(String)
    end

    it "responds to adapter (for self-reference compatibility)" do
      expect(adapter).to respond_to(:adapter)
    end
  end

  # Session management
  describe "session management" do
    it { expect(adapter).to respond_to(:login) }
    it { expect(adapter).to respond_to(:logout) }
    it { expect(adapter).to respond_to(:authenticated_request) }
  end

  # Power management (Core::Power)
  describe "power management" do
    it { expect(adapter).to respond_to(:power_status) }
    it { expect(adapter).to respond_to(:power_on) }
    it { expect(adapter).to respond_to(:power_off) }
    it { expect(adapter).to respond_to(:power_restart) }
    it { expect(adapter).to respond_to(:power_cycle) }
    it { expect(adapter).to respond_to(:reset_type_allowed) }
  end

  # System information (Core::System)
  describe "system information" do
    it { expect(adapter).to respond_to(:system_info) }
    it { expect(adapter).to respond_to(:service_tag) }
    it { expect(adapter).to respond_to(:make) }
    it { expect(adapter).to respond_to(:model) }
    it { expect(adapter).to respond_to(:serial) }
    it { expect(adapter).to respond_to(:cpus) }
    it { expect(adapter).to respond_to(:memory) }
    it { expect(adapter).to respond_to(:nics) }
    it { expect(adapter).to respond_to(:fans) }
    it { expect(adapter).to respond_to(:temperatures) }
    it { expect(adapter).to respond_to(:psus) }
    it { expect(adapter).to respond_to(:power_consumption) }
    it { expect(adapter).to respond_to(:power_consumption_watts) }
  end

  # Storage (Core::Storage)
  describe "storage" do
    it { expect(adapter).to respond_to(:storage_controllers) }
    it { expect(adapter).to respond_to(:drives) }
    it { expect(adapter).to respond_to(:volumes) }
    it { expect(adapter).to respond_to(:storage_summary) }
    it { expect(adapter).to respond_to(:volume_drives) }
  end

  # Virtual Media (Core::VirtualMedia)
  describe "virtual media" do
    it { expect(adapter).to respond_to(:virtual_media) }
    it { expect(adapter).to respond_to(:insert_virtual_media) }
    it { expect(adapter).to respond_to(:eject_virtual_media) }
    it { expect(adapter).to respond_to(:virtual_media_status) }
    it { expect(adapter).to respond_to(:mount_iso_and_boot) }
    it { expect(adapter).to respond_to(:unmount_all_media) }
  end

  # Boot configuration (Core::Boot)
  describe "boot configuration" do
    it { expect(adapter).to respond_to(:boot_config) }
    it { expect(adapter).to respond_to(:boot_options) }
    it { expect(adapter).to respond_to(:set_boot_override) }
    it { expect(adapter).to respond_to(:clear_boot_override) }
    it { expect(adapter).to respond_to(:set_boot_order) }
    it { expect(adapter).to respond_to(:get_boot_devices) }
    it { expect(adapter).to respond_to(:boot_to_pxe) }
    it { expect(adapter).to respond_to(:boot_to_disk) }
    it { expect(adapter).to respond_to(:boot_to_cd) }
    it { expect(adapter).to respond_to(:boot_to_usb) }
    it { expect(adapter).to respond_to(:boot_to_bios_setup) }
  end

  # Jobs/Tasks (Core::Jobs)
  describe "jobs and tasks" do
    it { expect(adapter).to respond_to(:jobs) }
    it { expect(adapter).to respond_to(:job_status) }
    it { expect(adapter).to respond_to(:wait_for_job) }
    it { expect(adapter).to respond_to(:cancel_job) }
    it { expect(adapter).to respond_to(:jobs_summary) }
  end

  # Network (Core::Network)
  describe "network configuration" do
    it { expect(adapter).to respond_to(:get_bmc_network) }
    it { expect(adapter).to respond_to(:set_bmc_network) }
  end

  # Utility (Core::Utility)
  describe "utility functions" do
    it { expect(adapter).to respond_to(:sel_log) }
    it { expect(adapter).to respond_to(:accounts) }
    it { expect(adapter).to respond_to(:sessions) }
    it { expect(adapter).to respond_to(:service_info) }
    it { expect(adapter).to respond_to(:get_firmware_version) }
  end

  # Extended methods commonly expected by applications
  describe "extended methods" do
    it { expect(adapter).to respond_to(:system_health) }
    it { expect(adapter).to respond_to(:bmc_info) }
  end

  # Optional but recommended
  describe "optional methods" do
    it "may respond to pci_devices" do
      # Not required but commonly used
      if adapter.respond_to?(:pci_devices)
        expect(adapter.method(:pci_devices).arity).to eq(0)
      end
    end
  end
end

# Shared examples for testing adapter with a live/mocked connection
RSpec.shared_examples "a connected radfish adapter" do
  describe "power methods return expected types" do
    it "power_status returns a string" do
      expect(adapter.power_status).to be_a(String)
    end

    it "reset_type_allowed returns an array" do
      expect(adapter.reset_type_allowed).to be_an(Array)
    end
  end

  describe "system methods return expected types" do
    it "system_info returns a hash" do
      expect(adapter.system_info).to be_a(Hash)
    end

    it "cpus returns an array" do
      expect(adapter.cpus).to be_an(Array)
    end

    it "memory returns an array" do
      expect(adapter.memory).to be_an(Array)
    end

    it "nics returns an array" do
      expect(adapter.nics).to be_an(Array)
    end

    it "fans returns an array" do
      expect(adapter.fans).to be_an(Array)
    end

    it "temperatures returns an array" do
      expect(adapter.temperatures).to be_an(Array)
    end

    it "psus returns an array" do
      expect(adapter.psus).to be_an(Array)
    end

    it "power_consumption_watts returns a number" do
      expect(adapter.power_consumption_watts).to be_a(Numeric)
    end

    it "system_health responds to .health or is a string" do
      health = adapter.system_health
      expect(health.respond_to?(:health) || health.is_a?(String)).to be true
    end
  end

  describe "storage methods return expected types" do
    it "storage_controllers returns an array" do
      expect(adapter.storage_controllers).to be_an(Array)
    end

    it "storage_summary returns a hash with controller_count" do
      summary = adapter.storage_summary
      expect(summary).to be_a(Hash)
      expect(summary).to have_key(:controller_count).or have_key("controller_count")
    end
  end

  describe "virtual media methods return expected types" do
    it "virtual_media returns an array" do
      expect(adapter.virtual_media).to be_an(Array)
    end

    it "virtual_media_status returns an array" do
      expect(adapter.virtual_media_status).to be_an(Array)
    end
  end

  describe "boot methods return expected types" do
    it "boot_config returns a hash" do
      expect(adapter.boot_config).to be_a(Hash)
    end

    it "boot_options returns a hash or array" do
      opts = adapter.boot_options
      expect(opts.is_a?(Hash) || opts.is_a?(Array)).to be true
    end

    it "get_boot_devices returns an array" do
      expect(adapter.get_boot_devices).to be_an(Array)
    end
  end

  describe "jobs methods return expected types" do
    it "jobs returns an array" do
      expect(adapter.jobs).to be_an(Array)
    end

    it "jobs_summary returns a hash" do
      expect(adapter.jobs_summary).to be_a(Hash)
    end
  end

  describe "network methods return expected types" do
    it "get_bmc_network returns a hash" do
      expect(adapter.get_bmc_network).to be_a(Hash)
    end
  end

  describe "utility methods return expected types" do
    it "sel_log returns an array" do
      expect(adapter.sel_log).to be_an(Array)
    end

    it "accounts returns an array" do
      expect(adapter.accounts).to be_an(Array)
    end

    it "sessions returns an array" do
      expect(adapter.sessions).to be_an(Array)
    end

    it "bmc_info returns a hash" do
      expect(adapter.bmc_info).to be_a(Hash)
    end
  end

  describe "hardware components have expected accessors" do
    it "cpus have socket accessor" do
      cpus = adapter.cpus
      if cpus.any?
        cpu = cpus.first
        expect(cpu.respond_to?(:socket) || cpu.respond_to?(:[]) && cpu["socket"]).to be true
      end
    end

    it "memory items have capacity_bytes" do
      memory = adapter.memory
      if memory.any?
        dimm = memory.first
        expect(dimm.respond_to?(:capacity_bytes) || dimm.respond_to?(:[]) && dimm["capacity_bytes"]).to be true
      end
    end

    it "nics have mac accessor" do
      nics = adapter.nics
      if nics.any?
        nic = nics.first
        expect(nic.respond_to?(:mac) || nic.respond_to?(:[]) && nic["mac"]).to be true
      end
    end

    it "fans have name and rpm" do
      fans = adapter.fans
      if fans.any?
        fan = fans.first
        has_name = fan.respond_to?(:name) || (fan.respond_to?(:[]) && fan["name"])
        has_rpm = fan.respond_to?(:rpm) || (fan.respond_to?(:[]) && fan["rpm"])
        expect(has_name && has_rpm).to be true
      end
    end

    it "temperatures have reading_celsius" do
      temps = adapter.temperatures
      if temps.any?
        temp = temps.first
        expect(temp.respond_to?(:reading_celsius) || temp.respond_to?(:[]) && temp["reading_celsius"]).to be true
      end
    end

    it "psus have status" do
      psus = adapter.psus
      if psus.any?
        psu = psus.first
        expect(psu.respond_to?(:status) || psu.respond_to?(:[]) && psu["status"]).to be true
      end
    end
  end
end

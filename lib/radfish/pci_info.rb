# frozen_string_literal: true

module Radfish
  class PciInfo
    attr_reader :client
    
    def initialize(client)
      @client = client
      @cache = {}
    end
    
    # Get all PCI devices
    def devices
      @cache[:devices] ||= @client.adapter.pci_devices
    end
    
    # Get NICs with PCI slot information
    def nics_with_slots
      @cache[:nics_with_slots] ||= @client.adapter.nics_with_pci_info
    end
    
    # Find PCI devices by manufacturer
    def devices_by_manufacturer(manufacturer)
      devices.select { |d| d.manufacturer&.match?(/#{manufacturer}/i) }
    end
    
    # Find Mellanox devices
    def mellanox_devices
      devices_by_manufacturer('Mellanox')
    end
    
    # Get network controllers
    def network_controllers
      devices.select { |d| d.device_class&.match?(/NetworkController/i) }
    end
  end
end
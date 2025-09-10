# frozen_string_literal: true

module Radfish
  # Lightweight value object representing a storage controller.
  # Holds a stable identifier and optional name.
  class Controller
    attr_reader :id, :name, :model, :vendor, :adapter_data, :firmware_version, 
                :encryption_mode, :encryption_capability, :controller_type, 
                :pci_slot, :status, :drives_count

    def initialize(client:, id:, name: nil, model: nil, vendor: nil, adapter_data: nil,
                   firmware_version: nil, encryption_mode: nil, encryption_capability: nil,
                   controller_type: nil, pci_slot: nil, status: nil, drives_count: nil)
      @client = client
      @id = id
      @name = name
      @model = model
      @vendor = vendor
      @adapter_data = adapter_data
      @firmware_version = firmware_version
      @encryption_mode = encryption_mode
      @encryption_capability = encryption_capability
      @controller_type = controller_type
      @pci_slot = pci_slot
      @status = status
      @drives_count = drives_count
    end

    # Convenience accessors delegate to the client wrappers
    def drives
      @client.drives(self)
    end

    def volumes
      @client.volumes(self)
    end

    def to_h
      { 
        id: id, 
        name: name, 
        model: model, 
        vendor: vendor,
        firmware_version: firmware_version,
        encryption_mode: encryption_mode,
        encryption_capability: encryption_capability,
        controller_type: controller_type,
        pci_slot: pci_slot,
        status: status,
        drives_count: drives_count
      }.compact
    end

    def ==(other)
      other.is_a?(Controller) && other.id == id && other.vendor.to_s == vendor.to_s
    end
  end
end

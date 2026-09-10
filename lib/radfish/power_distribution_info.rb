# frozen_string_literal: true

module Radfish
  # Vendor-neutral facade over a PDU's Redfish PowerDistribution resource, shaped like
  # SystemInfo. `to_h` memoizes the single adapter call; every reader is a field of that
  # hash. `raw` exposes the full parsed resource for OEM electrical fields.
  class PowerDistributionInfo
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def keys
      %i[vendor manufacturer model part_number serial serial_number
         firmware_version equipment_type raw]
    end

    def to_h
      @to_h ||= @client.adapter.power_distribution_info
    end

    def vendor
      to_h[:vendor]
    end

    def manufacturer
      to_h[:manufacturer]
    end

    def model
      to_h[:model]
    end

    def part_number
      to_h[:part_number]
    end

    def serial
      to_h[:serial]
    end

    def serial_number
      to_h[:serial_number]
    end

    def firmware_version
      to_h[:firmware_version]
    end

    def equipment_type
      to_h[:equipment_type]
    end

    def raw
      to_h[:raw]
    end
  end
end

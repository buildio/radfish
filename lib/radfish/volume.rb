# frozen_string_literal: true

module Radfish
  class Volume
    attr_reader :id, :name, :capacity_bytes, :capacity_gb, :raid_type,
                :status, :encrypted, :adapter_data, :controller

    def initialize(client:, controller:, id: nil, name: nil, capacity_bytes: nil,
                   capacity_gb: nil, raid_type: nil, status: nil, encrypted: nil,
                   adapter_data: nil)
      @client = client
      @controller = controller
      @id = id
      @name = name
      @capacity_bytes = capacity_bytes
      @capacity_gb = capacity_gb || (capacity_bytes ? (capacity_bytes.to_f / (1000**3)).round(2) : nil)
      @raid_type = raid_type
      @status = status
      @encrypted = encrypted
      @adapter_data = adapter_data
    end

    def drives
      @client.adapter.volume_drives(self)
    end

    def to_h
      {
        id: id,
        name: name,
        capacity_bytes: capacity_bytes,
        capacity_gb: capacity_gb,
        raid_type: raid_type,
        status: status,
        encrypted: encrypted
      }.compact
    end
  end
end


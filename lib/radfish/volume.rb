# frozen_string_literal: true

module Radfish
  class Volume
    # Canonical, normalized attributes only.
    attr_reader :id, :name, :capacity_bytes, :raid_type, :volume_type, :drives,
                :encrypted, :lock_status, :stripe_size,
                :operation_percent_complete, :operation_name,
                :write_cache_policy, :read_cache_policy, :health,
                :adapter_data, :controller

    def initialize(client:, controller:, id: nil, name: nil, capacity_bytes: nil,
                   raid_type: nil, volume_type: nil, drives: nil, encrypted: nil,
                   lock_status: nil, stripe_size: nil,
                   operation_percent_complete: nil, operation_name: nil,
                   write_cache_policy: nil, read_cache_policy: nil,
                   health: nil, adapter_data: nil)
      @client = client
      @controller = controller
      @id = id
      @name = name
      @capacity_bytes = capacity_bytes
      @raid_type = raid_type
      @volume_type = volume_type
      @drives = Array(drives) # normalized list of drive reference ids (e.g., @odata.id)
      @encrypted = encrypted
      @lock_status = lock_status
      @stripe_size = stripe_size
      @operation_percent_complete = operation_percent_complete
      @operation_name = operation_name
      @write_cache_policy = write_cache_policy
      @read_cache_policy = read_cache_policy
      @health = health
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
        raid_type: raid_type,
        volume_type: volume_type,
        drives: drives,
        encrypted: encrypted,
        lock_status: lock_status,
        stripe_size: stripe_size,
        operation_percent_complete: operation_percent_complete,
        operation_name: operation_name,
        write_cache_policy: write_cache_policy,
        read_cache_policy: read_cache_policy,
        health: health
      }.compact
    end
  end
end

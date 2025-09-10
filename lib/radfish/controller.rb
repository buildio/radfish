# frozen_string_literal: true

module Radfish
  # Lightweight value object representing a storage controller.
  # Holds a stable identifier and optional name.
  class Controller
    attr_reader :id, :name, :vendor, :adapter_data

    def initialize(client:, id:, name: nil, vendor: nil, adapter_data: nil)
      @client = client
      @id = id
      @name = name
      @vendor = vendor
      @adapter_data = adapter_data
    end

    # Convenience accessors delegate to the client wrappers
    def drives
      @client.drives(self)
    end

    def volumes
      @client.volumes(self)
    end

    def to_h
      { id: id, name: name, vendor: vendor }
    end

    def ==(other)
      other.is_a?(Controller) && other.id == id && other.vendor.to_s == vendor.to_s
    end
  end
end

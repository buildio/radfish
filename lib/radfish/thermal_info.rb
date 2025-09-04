# frozen_string_literal: true

module Radfish
  class ThermalInfo
    attr_reader :client
    
    def initialize(client)
      @client = client
      @cache = {}
    end
    
    def keys
      [:fans]
    end
    
    def to_h
      keys.each_with_object({}) do |key, hash|
        hash[key] = send(key) rescue nil
      end
    end
    
    def fans
      @cache[:fans] ||= @client.adapter.fans
    end
  end
end
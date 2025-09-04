# frozen_string_literal: true

module Radfish
  class SystemInfo
    attr_reader :client
    
    def initialize(client)
      @client = client
      @cache = {}
    end
    
    def keys
      [:service_tag, :make, :model, :serial, :cpus, :memory, :nics, :fans, :psus, :health, :controllers]
    end
    
    def to_h
      keys.each_with_object({}) do |key, hash|
        hash[key] = send(key)
      end
    end
    
    def service_tag
      fetch_system_info[:service_tag]
    end
    
    def make
      fetch_system_info[:manufacturer] || fetch_system_info[:make]
    end
    
    def model
      fetch_system_info[:model]
    end
    
    def serial
      fetch_system_info[:serial_number] || fetch_system_info[:serial]
    end
    
    def cpus
      @cache[:cpus] ||= @client.adapter.cpus
    end
    
    def memory
      @cache[:memory] ||= @client.adapter.memory
    end
    
    def nics
      @cache[:nics] ||= @client.adapter.nics
    end
    
    def fans
      @cache[:fans] ||= @client.adapter.fans
    end
    
    # Removed temperatures - not universally supported
    
    def psus
      @cache[:psus] ||= @client.adapter.psus
    end
    
    def health
      @cache[:health] ||= @client.adapter.system_health
    end
    
    def controllers
      @cache[:controllers] ||= @client.adapter.storage_controllers
    end
    
    private
    
    def fetch_system_info
      @cache[:system_info] ||= @client.adapter.system_info
    end
  end
end
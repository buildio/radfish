# frozen_string_literal: true

module Radfish
  class PowerInfo
    attr_reader :client
    
    def initialize(client)
      @client = client
      @cache = {}
    end
    
    def keys
      [:state, :usage_watts, :capacity_watts, :allocated_watts, :reset_types_allowed, :psus, :on, :off, :restart, :cycle]
    end
    
    def to_h
      # Only include data attributes, not methods
      data_keys = [:state, :usage_watts, :capacity_watts, :allocated_watts, :reset_types_allowed, :psus]
      data_keys.each_with_object({}) do |key, hash|
        hash[key] = send(key) rescue nil
      end
    end
    
    def state
      fetch_power_status[:power_state] || fetch_power_status[:state]
    end
    
    def usage_watts
      fetch_power_consumption[:consumed_watts] || 
        fetch_power_consumption[:power_usage_watts] || 
        fetch_power_consumption_watts
    end
    
    def capacity_watts
      fetch_power_consumption[:capacity_watts] || fetch_power_consumption[:power_capacity_watts]
    end
    
    def allocated_watts
      fetch_power_consumption[:allocated_watts] || fetch_power_consumption[:power_allocated_watts]
    end
    
    def on
      @client.adapter.power_on
    end
    
    def off(force: false)
      @client.adapter.power_off(force: force)
    end
    
    def restart(force: false)
      @client.adapter.power_restart(force: force)
    end
    
    def cycle
      @client.adapter.power_cycle
    end
    
    def reset_types_allowed
      @cache[:reset_types] ||= @client.adapter.reset_type_allowed if @client.adapter.respond_to?(:reset_type_allowed)
    end
    
    def psus
      @cache[:psus] ||= @client.adapter.psus
    end
    
    private
    
    def fetch_power_status
      @cache[:power_status] ||= begin
        if @client.adapter.respond_to?(:power_status)
          status = @client.adapter.power_status
          case status
          when Hash
            status
          when String, Symbol
            { power_state: status.to_s }
          else
            { power_state: status }
          end
        else
          {}
        end
      end
    end
    
    def fetch_power_consumption
      @cache[:power_consumption] ||= begin
        if @client.adapter.respond_to?(:power_consumption)
          @client.adapter.power_consumption
        else
          {}
        end
      end
    end
    
    def fetch_power_consumption_watts
      @cache[:power_consumption_watts] ||= begin
        if @client.adapter.respond_to?(:power_consumption_watts)
          @client.adapter.power_consumption_watts
        else
          nil
        end
      end
    end
  end
end
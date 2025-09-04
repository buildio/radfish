# frozen_string_literal: true

module Radfish
  class BmcInfo
    attr_reader :client
    
    def initialize(client)
      @client = client
      @cache = {}
    end
    
    def keys
      [:license_version, :firmware_version, :redfish_version, :mac_address, :ip_address, :hostname, :health]
    end
    
    def to_h
      keys.each_with_object({}) do |key, hash|
        hash[key] = send(key)
      end
    end
    
    def license_version
      fetch_bmc_info[:license_version] || fetch_bmc_info[:bmc_license_version]
    end
    
    def firmware_version
      fetch_bmc_info[:firmware_version] || fetch_bmc_info[:bmc_firmware_version]
    end
    
    def redfish_version
      fetch_bmc_info[:redfish_version]
    end
    
    def mac_address
      fetch_bmc_info[:mac_address] || fetch_bmc_info[:bmc_mac_address]
    end
    
    def ip_address
      fetch_bmc_info[:ip_address] || fetch_bmc_info[:bmc_ip_address]
    end
    
    def hostname
      fetch_bmc_info[:hostname] || fetch_bmc_info[:bmc_hostname]
    end
    
    def health
      fetch_bmc_info[:health] || fetch_bmc_info[:bmc_health]
    end
    
    private
    
    def fetch_bmc_info
      @cache[:bmc_info] ||= begin
        if @client.adapter.respond_to?(:bmc_info)
          @client.adapter.bmc_info
        elsif @client.adapter.respond_to?(:system_info)
          # Extract BMC-related info from system_info if no dedicated method
          info = @client.adapter.system_info
          {
            firmware_version: info[:bmc_firmware_version] || info[:firmware_version],
            license_version: info[:bmc_license_version] || info[:license_version],
            redfish_version: info[:redfish_version],
            mac_address: info[:bmc_mac_address],
            ip_address: info[:bmc_ip_address],
            hostname: info[:bmc_hostname],
            health: info[:bmc_health]
          }
        else
          {}
        end
      end
    end
  end
end
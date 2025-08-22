# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'openssl'

module Radfish
  class VendorDetector
    
    attr_reader :host, :username, :password, :port, :use_ssl, :verify_ssl
    attr_accessor :verbosity
    
    def initialize(host:, username:, password:, port: 443, use_ssl: true, verify_ssl: false)
      @host = host
      @username = username
      @password = password
      @port = port
      @use_ssl = use_ssl
      @verify_ssl = verify_ssl
      @verbosity = 0
    end
    
    def detect
      puts "Detecting vendor for #{host}..." if @verbosity && @verbosity > 0
      
      # Try to get the Redfish service root
      service_root = fetch_service_root
      return nil unless service_root
      
      vendor = identify_vendor(service_root)
      puts "Detected vendor: #{vendor || 'Unknown'}" if @verbosity && @verbosity > 0
      
      vendor
    end
    
    private
    
    def fetch_service_root
      uri = URI("#{base_url}/redfish/v1")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = use_ssl
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless verify_ssl
      http.open_timeout = 5
      http.read_timeout = 10
      
      req = Net::HTTP::Get.new(uri)
      req.basic_auth(username, password)
      req['Accept'] = 'application/json'
      
      begin
        res = http.request(req)
        
        if res.code.to_i == 200
          JSON.parse(res.body)
        else
          puts "Failed to fetch service root: HTTP #{res.code}" if @verbosity && @verbosity > 0
          nil
        end
      rescue => e
        puts "Error fetching service root: #{e.message}" if @verbosity && @verbosity > 0
        nil
      end
    end
    
    def identify_vendor(service_root)
      # Check explicit vendor field
      vendor = service_root['Vendor'] || service_root['Oem']&.keys&.first
      
      if vendor
        return normalize_vendor(vendor)
      end
      
      # Try to identify by product name
      product = service_root['Product']
      if product
        case product
        when /dell/i, /poweredge/i, /idrac/i
          return 'dell'
        when /supermicro/i, /smc/i
          return 'supermicro'
        when /hpe/i, /hewlett/i, /proliant/i, /ilo/i
          return 'hpe'
        when /lenovo/i, /thinkserver/i, /thinksystem/i
          return 'lenovo'
        when /asrockrack/i, /asrock/i
          return 'asrockrack'
        end
      end
      
      # Check manager endpoint for more clues
      managers_url = service_root.dig('Managers', '@odata.id')
      if managers_url
        vendor_from_managers = detect_from_managers(managers_url)
        return vendor_from_managers if vendor_from_managers
      end
      
      # Default to generic if we can't determine
      'generic'
    end
    
    def detect_from_managers(managers_path)
      uri = URI("#{base_url}#{managers_path}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = use_ssl
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless verify_ssl
      http.open_timeout = 5
      http.read_timeout = 10
      
      req = Net::HTTP::Get.new(uri)
      req.basic_auth(username, password)
      req['Accept'] = 'application/json'
      
      begin
        res = http.request(req)
        
        if res.code.to_i == 200
          data = JSON.parse(res.body)
          
          # Check first manager
          if data['Members'] && data['Members'].first
            manager_url = data['Members'].first['@odata.id']
            
            # Dell uses iDRAC.Embedded.1
            return 'dell' if manager_url.include?('iDRAC')
            
            # HPE uses numbered managers like /redfish/v1/Managers/1
            # Supermicro also uses /redfish/v1/Managers/1
            # Need to fetch actual manager data
            
            manager_data = fetch_manager(manager_url)
            if manager_data
              # Check manager model/description
              model = manager_data['Model'] || ''
              description = manager_data['Description'] || ''
              # firmware = manager_data['FirmwareVersion'] || ''  # Reserved for future use
              
              return 'dell' if model.match?(/idrac/i) || description.match?(/idrac/i)
              return 'hpe' if model.match?(/ilo/i) || description.match?(/ilo/i)
              return 'supermicro' if model.match?(/supermicro/i) || description.match?(/smc/i)
              return 'lenovo' if model.match?(/lenovo/i) || description.match?(/xcc/i)
              return 'asrockrack' if model.match?(/asrock/i)
            end
          end
        end
      rescue => e
        puts "Error detecting from managers: #{e.message}" if @verbosity && @verbosity > 1
      end
      
      nil
    end
    
    def fetch_manager(manager_path)
      uri = URI("#{base_url}#{manager_path}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = use_ssl
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless verify_ssl
      http.open_timeout = 5
      http.read_timeout = 10
      
      req = Net::HTTP::Get.new(uri)
      req.basic_auth(username, password)
      req['Accept'] = 'application/json'
      
      begin
        res = http.request(req)
        JSON.parse(res.body) if res.code.to_i == 200
      rescue => e
        puts "Error fetching manager: #{e.message}" if @verbosity && @verbosity > 1
        nil
      end
    end
    
    def normalize_vendor(vendor_string)
      case vendor_string.to_s.downcase
      when /dell/i, /idrac/i
        'dell'
      when /supermicro/i, /smc/i
        'supermicro'
      when /hpe/i, /hewlett/i, /hp/i, /ilo/i
        'hpe'
      when /lenovo/i
        'lenovo'
      when /asrock/i
        'asrockrack'
      else
        vendor_string.to_s.downcase
      end
    end
    
    def base_url
      protocol = use_ssl ? 'https' : 'http'
      "#{protocol}://#{host}:#{port}"
    end
  end
end
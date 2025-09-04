# frozen_string_literal: true

require 'json'

module Radfish
  class VendorDetector
    include Debuggable
    
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
      
      # Use the shared HTTP client
      @http_client = HttpClient.new(
        host: host,
        port: port,
        use_ssl: use_ssl,
        verify_ssl: verify_ssl,
        username: username,
        password: password,
        verbosity: 0,  # Will be updated via verbosity= setter
        retry_count: 2,  # Fewer retries for detection
        retry_delay: 0.5
      )
    end
    
    def verbosity=(value)
      @verbosity = value
      @http_client.verbosity = value if @http_client
    end
    
    def detect
      debug "Detecting vendor for #{host}:#{port}...", 1, :cyan
      
      # Try to get the Redfish service root
      service_root = fetch_service_root
      
      unless service_root
        debug "Failed to fetch service root from #{host}:#{port}", 1, :red
        return nil
      end
      
      vendor = identify_vendor(service_root)
      debug "Detected vendor: #{vendor || 'Unknown'} for #{host}:#{port}", 1, vendor ? :green : :yellow
      
      vendor
    end
    
    private
    
    def fetch_service_root
      begin
        # Use a shorter timeout for vendor detection (5 seconds total)
        response = @http_client.get('/redfish/v1', timeout: 5)
        
        if response.status == 200
          JSON.parse(response.body)
        elsif response.status == 401
          debug "Authentication failed (HTTP 401) - check username/password", 1, :red
          nil
        elsif response.status == 404
          debug "Redfish API not found at /redfish/v1 (HTTP 404)", 1, :red
          nil
        else
          debug "Failed to fetch service root: HTTP #{response.status}", 1, :red
          debug "Response body: #{response.body[0..200]}" if response.body && @verbosity >= 2
          nil
        end
      rescue ConnectionError, TimeoutError => e
        debug "Connection failed to #{host}:#{port} - #{e.message}", 1, :red
        nil
      rescue JSON::ParserError => e
        debug "Invalid JSON response from BMC: #{e.message}", 1, :red
        nil
      rescue Faraday::ConnectionFailed => e
        debug "Connection refused or failed to #{host}:#{port} - #{e.message}", 1, :red
        nil
      rescue Faraday::TimeoutError => e
        debug "Request timed out to #{host}:#{port} - #{e.message}", 1, :red
        nil
      rescue => e
        debug "Unexpected error fetching service root: #{e.class} - #{e.message}", 1, :red
        debug "Backtrace: #{e.backtrace.first(3).join("\n")}" if @verbosity >= 2
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
      begin
        response = @http_client.get(managers_path)
        
        if response.status == 200
          data = JSON.parse(response.body)
          
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
              
              return 'dell' if model.match?(/idrac/i) || description.match?(/idrac/i)
              return 'hpe' if model.match?(/ilo/i) || description.match?(/ilo/i)
              return 'supermicro' if model.match?(/supermicro/i) || description.match?(/smc/i)
              return 'lenovo' if model.match?(/lenovo/i) || description.match?(/xcc/i)
              return 'asrockrack' if model.match?(/asrock/i)
            end
          end
        end
      rescue => e
        debug "Error detecting from managers: #{e.message}", 3, :yellow
      end
      
      nil
    end
    
    def fetch_manager(manager_path)
      begin
        response = @http_client.get(manager_path)
        JSON.parse(response.body) if response.status == 200
      rescue => e
        debug "Error fetching manager: #{e.message}", 3, :yellow
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
  end
end
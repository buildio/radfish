# frozen_string_literal: true

require 'json'

module Radfish
  class VendorDetector
    include Debuggable
    
    attr_reader :host, :username, :password, :port, :use_ssl, :verify_ssl
    attr_accessor :verbosity
    
    def initialize(host:, username:, password:, port: 443, use_ssl: true, verify_ssl: false, host_header: nil)
      @host = host
      @username = username
      @password = password
      @port = port
      @use_ssl = use_ssl
      @verify_ssl = verify_ssl
      @host_header = host_header
      @verbosity = 0
      
      # Use the shared HTTP client
      @http_client = HttpClient.new(
        host: host,
        port: port,
        use_ssl: use_ssl,
        verify_ssl: verify_ssl,
        username: username,
        password: password,
        host_header: host_header,  # Pass host_header to HttpClient
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
      debug "Host header: #{@host_header}" if @host_header
      
      # Try to get the Redfish service root
      debug "Fetching service root...", 2, :yellow
      service_root = fetch_service_root
      
      unless service_root
        debug "Failed to fetch service root from #{host}:#{port}", 1, :red
        return nil
      end
      
      debug "Service root fetched successfully", 2, :green
      vendor = identify_vendor(service_root)
      debug "Detected vendor: #{vendor || 'Unknown'} for #{host}:#{port}", 1, vendor ? :green : :yellow
      
      vendor
    end
    
    private

    def check_response(response)
      if response.status == 200
        debug "Got 200 response, parsing JSON...", 2, :green
        JSON.parse(response.body)
      elsif HttpClient::REDIRECT_STATUSES.include?(response.status)
        # HttpClient follows redirects that stay on this endpoint, so reaching
        # here means it refused one or ran out of them.
        debug "Redirect to #{response['location'].inspect} was not followed (HTTP #{response.status})", 1, :red
        nil
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
    end

    def fetch_service_root
      begin
        debug "About to make HTTP GET request to /redfish/v1", 2, :yellow
        # Use longer timeout for SSH tunnels (15 seconds), shorter for direct connections (5 seconds)
        timeout = @host_header ? 15 : 5
        debug "Using timeout: #{timeout}s (SSH tunnel detected)" if @host_header
        response = @http_client.get('/redfish/v1', timeout: timeout)
        debug "HTTP GET request completed", 2, :green

        check_response(response)
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
          return 'ami'
        when /ami/i, /megarac/i
          return 'ami'
        end
      end
      
      # Check manager endpoint for more clues
      managers_url = service_root.dig('Managers', '@odata.id')
      if managers_url
        vendor_from_managers = detect_from_managers(managers_url)
        return vendor_from_managers if vendor_from_managers
      end

      # No server vendor matched. This may be a PDU (DMTF PowerDistribution) rather
      # than a BMC, so probe for one before giving up.
      pdu_vendor = detect_pdu(service_root)
      return pdu_vendor if pdu_vendor

      # Default to generic if we can't determine
      'generic'
    end

    # Probe for a Redfish PowerDistribution resource. Follow the service root's
    # PowerEquipment link when present, else try /redfish/v1/PowerDistribution/1
    # directly. Map Manufacturer/Oem/Model to a PDU brand, or 'generic_pdu' when the
    # body looks like a PowerDistribution but the brand is unknown. Any error skips PDU
    # detection and lets the caller fall through to existing behavior.
    def detect_pdu(service_root)
      path = service_root.dig('PowerEquipment', '@odata.id') || PduAdapter::POWER_DISTRIBUTION_PATH
      data = fetch_pdu_json(path)
      return nil unless data.is_a?(Hash)

      # A PowerEquipment aggregator is not itself a PDU; follow it to the first one.
      data = follow_to_pdu(data) unless PduAdapter.power_distribution?(data)
      return nil unless PduAdapter.power_distribution?(data)

      vendor = PduAdapter.vendor_from(data) || 'generic_pdu'
      debug "Detected PDU vendor: #{vendor}", 1, :green
      vendor
    rescue => e
      debug "PDU detection error: #{e.class} - #{e.message}", 3, :yellow
      nil
    end

    # Given a PowerEquipment aggregator, follow one level to a concrete PDU resource:
    # its first PDU-collection link, then that collection's first member.
    def follow_to_pdu(equipment)
      collection_link = %w[RackPDUs FloorPDUs PowerShelves TransferSwitches Switchgear]
                        .map { |key| equipment.dig(key, '@odata.id') }.compact.first
      return nil unless collection_link

      collection = fetch_pdu_json(collection_link)
      member = collection&.dig('Members', 0, '@odata.id')
      return nil unless member

      fetch_pdu_json(member)
    end

    def fetch_pdu_json(path)
      response = @http_client.get(path)
      return nil unless response.status == 200

      JSON.parse(response.body)
    rescue => e
      debug "PDU probe failed for #{path}: #{e.message}", 3, :yellow
      nil
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
              return 'ami' if model.match?(/asrock/i) || description.match?(/asrock/i)
              return 'ami' if description.match?(/bmc/i) && manager_data.dig('Oem', 'Ami')
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
        'ami'
      when /ami/i, /megarac/i
        'ami'
      else
        vendor_string.to_s.downcase
      end
    end
  end
end

# frozen_string_literal: true

module Radfish
  module Core
    class BaseClient
      include Debuggable
      
      attr_reader :host, :username, :password, :port, :use_ssl, :verify_ssl, :host_header
      attr_accessor :verbosity, :retry_count, :retry_delay
      
      def initialize(host:, username:, password:, port: 443, use_ssl: true, verify_ssl: false, 
                     retry_count: 3, retry_delay: 1, host_header: nil, **options)
        @host = host
        @username = username
        @password = password
        @port = port
        @use_ssl = use_ssl
        @verify_ssl = verify_ssl
        @host_header = host_header
        @verbosity = 0
        @retry_count = retry_count
        @retry_delay = retry_delay
        
        # Store any vendor-specific options
        @options = options
      end
      
      def base_url
        protocol = use_ssl ? 'https' : 'http'
        "#{protocol}://#{host}:#{port}"
      end
      
      def connection
        @connection ||= Faraday.new(url: base_url, ssl: { verify: verify_ssl }) do |faraday|
          faraday.request :multipart
          faraday.request :url_encoded
          faraday.adapter Faraday.default_adapter
          
          if @verbosity > 0
            faraday.response :logger, Logger.new(STDOUT), bodies: @verbosity >= 2 do |logger|
              logger.filter(/(Authorization: Basic )([^,\n]+)/, '\1[FILTERED]')
              logger.filter(/(Password"=>"?)([^,"]+)/, '\1[FILTERED]')
            end
          end
        end
      end
      
      def with_retries(max_retries = nil, initial_delay = nil, error_classes = nil)
        max_retries ||= @retry_count
        initial_delay ||= @retry_delay
        error_classes ||= [StandardError]
        
        retries = 0
        begin
          yield
        rescue *error_classes => e
          retries += 1
          if retries <= max_retries
            delay = initial_delay * (retries ** 1.5).to_i
            debug "RETRY: #{e.message} - Attempt #{retries}/#{max_retries}, waiting #{delay}s", 1, :yellow
            sleep delay
            retry
          else
            debug "MAX RETRIES REACHED: #{e.message} after #{max_retries} attempts", 1, :red
            raise e
          end
        end
      end
      
      # Vendor-specific methods to be overridden
      
      def vendor
        raise NotImplementedError, "Subclass must implement #vendor"
      end
      
      def login
        raise NotImplementedError, "Subclass must implement #login"
      end
      
      def logout
        raise NotImplementedError, "Subclass must implement #logout"
      end
      
      def authenticated_request(method, path, **options)
        raise NotImplementedError, "Subclass must implement #authenticated_request"
      end
      
      def redfish_version
        response = authenticated_request(:get, "/redfish/v1")
        if response.status == 200
          data = JSON.parse(response.body)
          data["RedfishVersion"]
        else
          raise Error, "Failed to get Redfish version: #{response.status}"
        end
      end
      
      def service_root
        response = authenticated_request(:get, "/redfish/v1")
        if response.status == 200
          JSON.parse(response.body)
        else
          raise Error, "Failed to get service root: #{response.status}"
        end
      end
      
      # Helper for handling responses
      def handle_response(response)
        if response.headers["location"]
          return handle_location(response.headers["location"])
        end
        
        if response.status.between?(200, 299)
          return response.body
        else
          raise Error, "Request failed: #{response.status} - #{response.body}"
        end
      end
      
      def handle_location(location)
        # Subclasses can override for vendor-specific handling
        nil
      end
    end
  end
end
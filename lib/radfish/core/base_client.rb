# frozen_string_literal: true

require 'logger'

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
        
        # Create the HTTP client
        @http_client = HttpClient.new(
          host: host,
          port: port,
          use_ssl: use_ssl,
          verify_ssl: verify_ssl,
          username: username,
          password: password,
          verbosity: verbosity,
          retry_count: retry_count,
          retry_delay: retry_delay
        )
      end
      
      def base_url
        @http_client.base_url
      end
      
      def verbosity=(value)
        @verbosity = value
        @http_client.verbosity = value if @http_client
      end
      
      # Delegate HTTP methods to the client
      def http_get(path, **options)
        @http_client.get(path, **options)
      end
      
      def http_post(path, **options)
        @http_client.post(path, **options)
      end
      
      def http_put(path, **options)
        @http_client.put(path, **options)
      end
      
      def http_patch(path, **options)
        @http_client.patch(path, **options)
      end
      
      def http_delete(path, **options)
        @http_client.delete(path, **options)
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
      
      protected
      
      # Access to the underlying HTTP client for subclasses
      def http_client
        @http_client
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
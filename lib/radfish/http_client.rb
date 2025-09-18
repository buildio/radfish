# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'logger'
require 'socket'

module Radfish
  # Shared HTTP client for all BMC connections
  class HttpClient
    include Debuggable
    
    attr_reader :host, :port, :use_ssl, :verify_ssl
    attr_accessor :username, :password, :verbosity, :retry_count, :retry_delay
    
    def initialize(host:, port: 443, use_ssl: true, verify_ssl: false, 
                   username: nil, password: nil, verbosity: 0,
                   retry_count: 3, retry_delay: 1, **options)
      @host = host
      @port = port
      @use_ssl = use_ssl
      @verify_ssl = verify_ssl
      @username = username
      @password = password
      @verbosity = verbosity
      @retry_count = retry_count
      @retry_delay = retry_delay
      @options = options
    end
    
    def base_url
      protocol = use_ssl ? 'https' : 'http'
      "#{protocol}://#{host}:#{port}"
    end
    
    def get(path, headers: {}, **options)
      request(:get, path, headers: headers, **options)
    end
    
    def post(path, body: nil, headers: {}, **options)
      request(:post, path, body: body, headers: headers, **options)
    end
    
    def put(path, body: nil, headers: {}, **options)
      request(:put, path, body: body, headers: headers, **options)
    end
    
    def patch(path, body: nil, headers: {}, **options)
      request(:patch, path, body: body, headers: headers, **options)
    end
    
    def delete(path, headers: {}, **options)
      request(:delete, path, headers: headers, **options)
    end
    
    def request(method, path, body: nil, headers: {}, auth: true, timeout: nil, **options)
      debug "Starting HTTP #{method.upcase} request to #{path}", 2, :yellow
      
      # Add host header if specified (needed for SSH tunnels to iDRAC)
      if @options[:host_header]
        headers = headers.merge('Host' => @options[:host_header])
        debug "Added Host header: #{@options[:host_header]}", 2, :cyan
      end
      
      debug "Creating connection...", 2, :yellow
      conn = connection(auth: auth)
      debug "Connection created, sending #{method} request...", 2, :yellow
      
      response = conn.send(method) do |req|
        debug "Setting request URL: #{path}", 3, :cyan
        req.url path
        debug "Merging headers: #{headers}", 3, :cyan
        req.headers.merge!(headers)
        req.body = body if body
        
        # Override timeout if specified
        if timeout
          debug "Setting timeout: #{timeout}s", 3, :cyan
          req.options.timeout = timeout
          req.options.open_timeout = [timeout / 2, 5].min
        end
        
        # Apply any additional options
        options.each do |key, value|
          req.options[key] = value if req.options.respond_to?(:"#{key}=")
        end
        debug "Request configured, about to send...", 2, :yellow
      end
      
      debug "Request completed with status: #{response.status}", 2, :green
      
      response
    rescue Faraday::ConnectionFailed => e
      debug "Connection failed: #{e.message}", 1, :red
      raise Radfish::ConnectionError, "Failed to connect to #{host}: #{e.message}"
    rescue Faraday::TimeoutError => e
      debug "Request timed out: #{e.message}", 1, :red
      raise Radfish::TimeoutError, "Request to #{host} timed out: #{e.message}"
    rescue Faraday::SSLError => e
      debug "SSL error: #{e.message}", 1, :red
      
      # Test if this might be HTTP instead of HTTPS
      begin
        debug "Testing if endpoint supports HTTP instead of HTTPS...", 2, :yellow
        test_http_socket = TCPSocket.new(host, port)
        test_http_socket.write("GET /redfish/v1 HTTP/1.1\r\nHost: #{@host_header || host}\r\nConnection: close\r\n\r\n")
        response = test_http_socket.read(1024) # Read first 1KB
        test_http_socket.close
        
        if response && response.include?("HTTP/") && !response.include?("301") && !response.include?("302")
          debug "HTTP response received - this endpoint might support HTTP instead of HTTPS", 1, :yellow
          debug "HTTP response preview: #{response[0..200]}", 2
        else
          debug "No valid HTTP response - endpoint requires HTTPS but SSL failed", 2, :red
        end
      rescue => http_test_error
        debug "HTTP test failed: #{http_test_error.message}", 2
      end
      
      raise Radfish::ConnectionError, "SSL error connecting to #{host}: #{e.message}"
    rescue => e
      debug "HTTP request failed: #{e.class} - #{e.message}", 1, :red
      debug "Exception backtrace: #{e.backtrace.first(5).join("\n")}", 1, :red
      
      # Don't re-raise as generic error - let the original exception propagate
      raise e
    end
    
    private
    
    def connection(auth: true)
      @connections ||= {}
      cache_key = auth ? :with_auth : :without_auth
      
      ssl_options = {
        verify: verify_ssl,
        verify_mode: verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE,
        # Try TLS 1.0 for older BMCs, fallback to 1.2
        min_version: OpenSSL::SSL::TLS1_VERSION,
        max_version: OpenSSL::SSL::TLS1_2_VERSION,
        ciphers: 'ALL:!aNULL:!eNULL:!SSLv2'  # More permissive for older BMCs
      }
      debug "SSL options: #{ssl_options.inspect}", 2, :yellow
      
      # Test TCP connectivity first (for SSH tunnels)
      if host.include?('localhost') && port
        begin
          debug "Testing TCP connectivity to #{host}:#{port}...", 2, :yellow
          socket = TCPSocket.new(host, port)
          socket.close
          debug "TCP connection test successful", 2, :green
        rescue => e
          debug "TCP connection test failed: #{e.message}", 1, :red
          raise Radfish::ConnectionError, "TCP connection test failed to #{host}:#{port}: #{e.message}"
        end
      end
      
      @connections[cache_key] ||= Faraday.new(url: base_url, ssl: ssl_options) do |faraday|
        # Add authentication if credentials provided and auth is enabled
        if auth && username && password
          faraday.request :authorization, :basic, username, password
        end
        
        # Standard headers
        faraday.headers['Accept'] = 'application/json'
        faraday.headers['Content-Type'] = 'application/json'
        faraday.headers['Connection'] = 'keep-alive'
        
        # Enable multipart for file uploads
        faraday.request :multipart
        faraday.request :url_encoded
        
        # Add retry middleware for robustness
        faraday.request :retry, {
          max: retry_count,
          interval: retry_delay,
          interval_randomness: 0.5,
          backoff_factor: 2,
          exceptions: [
            Faraday::ConnectionFailed,
            Faraday::TimeoutError,
            Faraday::RetriableResponse
          ],
          methods: [:get, :put, :delete, :post, :patch],
          retry_statuses: [408, 429, 500, 502, 503, 504]
          # Removed retry_block to debug ArgumentError - can add back later
        }
        
        # Set timeouts
        faraday.options.timeout = 30
        faraday.options.open_timeout = 10
        
        # Add logging if verbose
        if verbosity > 0
          faraday.response :logger, Logger.new(STDOUT), { bodies: verbosity >= 2 } do |logger|
            logger.filter(/(Authorization: Basic )([^,\n]+)/, '\1[FILTERED]')
            logger.filter(/(Password"=>"?)([^,"]+)/, '\1[FILTERED]')
            logger.filter(/("password":\s*")([^"]+)/, '\1[FILTERED]')
          end
        end
        
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
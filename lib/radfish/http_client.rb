# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'logger'

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
      response = connection(auth: auth).send(method) do |req|
        req.url path
        req.headers.merge!(headers)
        req.body = body if body
        
        # Override timeout if specified
        if timeout
          req.options.timeout = timeout
          req.options.open_timeout = [timeout / 2, 5].min
        end
        
        # Apply any additional options
        options.each do |key, value|
          req.options[key] = value if req.options.respond_to?(:"#{key}=")
        end
      end
      
      response
    rescue Faraday::ConnectionFailed => e
      debug "Connection failed: #{e.message}", 1, :red
      raise ConnectionError, "Failed to connect to #{host}: #{e.message}"
    rescue Faraday::TimeoutError => e
      debug "Request timed out: #{e.message}", 1, :red
      raise TimeoutError, "Request to #{host} timed out: #{e.message}"
    rescue Faraday::SSLError => e
      debug "SSL error: #{e.message}", 1, :red
      raise ConnectionError, "SSL error connecting to #{host}: #{e.message}"
    rescue => e
      debug "HTTP request failed: #{e.class} - #{e.message}", 1, :red
      raise Error, "HTTP request failed: #{e.message}"
    end
    
    private
    
    def connection(auth: true)
      @connections ||= {}
      cache_key = auth ? :with_auth : :without_auth
      
      @connections[cache_key] ||= Faraday.new(url: base_url, ssl: { verify: verify_ssl }) do |faraday|
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
          retry_statuses: [408, 429, 500, 502, 503, 504],
          retry_block: -> (env, options, retries, exception) {
            if verbosity > 0
              debug "Retry #{retries}/#{options[:max]}: #{exception&.message || "HTTP #{env.status}"}", 1, :yellow
            end
          }
        }
        
        # Set timeouts
        faraday.options.timeout = 30
        faraday.options.open_timeout = 10
        
        # Add logging if verbose
        if verbosity > 0
          faraday.response :logger, Logger.new(STDOUT), bodies: verbosity >= 2 do |logger|
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
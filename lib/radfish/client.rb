# frozen_string_literal: true

module Radfish
  class Client
    include Debuggable
    
    attr_reader :adapter, :vendor
    attr_accessor :verbosity
    
    def initialize(host:, username:, password:, vendor: nil, **options)
      @verbosity = options[:verbosity] || 0
      
      # Auto-detect vendor if not specified
      if vendor.nil?
        detector = VendorDetector.new(
          host: host,
          username: username,
          password: password,
          port: options[:port] || 443,
          use_ssl: options.fetch(:use_ssl, true),
          verify_ssl: options.fetch(:verify_ssl, false)
        )
        detector.verbosity = @verbosity
        @vendor = detector.detect
        
        if @vendor.nil?
          raise UnsupportedVendorError, "Could not detect vendor for #{host}:#{options[:port] || 443}. Please check: 1) The host is reachable, 2) Credentials are correct (#{username}), 3) The BMC supports Redfish API"
        end
        
        debug "Auto-detected vendor: #{@vendor}", 1, :green
      else
        @vendor = vendor.to_s.downcase
        debug "Using specified vendor: #{@vendor}", 1, :cyan
      end
      
      # Get the adapter class for this vendor
      adapter_class = Radfish.get_adapter(@vendor)
      
      if adapter_class.nil?
        # Try to load the adapter gem dynamically
        begin
          require "radfish/#{@vendor}_adapter"
          adapter_class = Radfish.get_adapter(@vendor)
        rescue LoadError
          # Adapter gem not installed
        end
      end
      
      if adapter_class.nil?
        raise UnsupportedVendorError, "No adapter available for vendor: #{@vendor}. " \
          "Please install the radfish-#{@vendor} gem or use a supported vendor."
      end
      
      # Create the adapter instance
      @adapter = adapter_class.new(
        host: host,
        username: username,
        password: password,
        **options
      )
      
      # Pass verbosity to adapter
      @adapter.verbosity = @verbosity if @adapter.respond_to?(:verbosity=)
    end
    
    def self.connect(host:, username:, password:, vendor: nil, **options)
      client = new(host: host, username: username, password: password, vendor: vendor, **options)
      
      if block_given?
        begin
          client.login
          yield client
        ensure
          client.logout
        end
      else
        client
      end
    end
    
    # Delegate all method calls to the adapter
    def method_missing(method, *args, **kwargs, &block)
      if @adapter.respond_to?(method)
        if kwargs.empty?
          @adapter.send(method, *args, &block)
        else
          @adapter.send(method, *args, **kwargs, &block)
        end
      else
        super
      end
    end
    
    def respond_to_missing?(method, include_private = false)
      @adapter.respond_to?(method, include_private) || super
    end
    
    # Core methods that should always be available
    
    def login
      @adapter.login
    end
    
    def logout
      @adapter.logout
    end
    
    def vendor_name
      @vendor
    end
    
    def adapter_class
      @adapter.class
    end
    
    # Lazy-loading API methods that return structured data
    
    def system
      @system ||= SystemInfo.new(self)
    end
    
    def bmc
      @bmc ||= BmcInfo.new(self)
    end
    
    def power
      @power ||= PowerInfo.new(self)
    end
    
    def thermal
      @thermal ||= ThermalInfo.new(self)
    end
    
    def pci
      @pci ||= PciInfo.new(self)
    end
    
    def service_tag
      # Get service_tag from system info
      system.service_tag
    end
    
    def supported_features
      # Return a list of features this adapter supports
      features = []
      
      # Check which modules are included
      features << :power if @adapter.respond_to?(:power_status)
      features << :system if @adapter.respond_to?(:system_info)
      features << :storage if @adapter.respond_to?(:storage_controllers)
      features << :virtual_media if @adapter.respond_to?(:virtual_media)
      features << :boot if @adapter.respond_to?(:boot_options)
      features << :jobs if @adapter.respond_to?(:jobs)
      features << :utility if @adapter.respond_to?(:sel_log)
      features << :network if @adapter.respond_to?(:get_bmc_network) || @adapter.respond_to?(:set_bmc_network)
      
      features
    end
    
    def info
      {
        vendor: @vendor,
        adapter: adapter_class.name,
        features: supported_features,
        host: @adapter.host,
        base_url: @adapter.base_url
      }
    end

    # Storage convenience API
    # Return normalized Controller objects while keeping adapter APIs intact.
    def controllers
      raw = @adapter.storage_controllers
      Array(raw).map { |c| build_controller(c) }
    end

    # Public storage API (not backward-compatible): require a Controller object.
    def drives(controller)
      raise ArgumentError, "Controller required" unless controller.is_a?(Controller)
      @adapter.drives(controller)
    end

    def volumes(controller)
      raise ArgumentError, "Controller required" unless controller.is_a?(Controller)
      @adapter.volumes(controller)
    end

    private

    def build_controller(raw)
      # Extract all available controller fields
      attrs = {}
      
      # Extract each field with both string and symbol key support
      %w[id name model firmware_version encryption_mode encryption_capability 
         controller_type pci_slot status drives_count].each do |field|
        attrs[field.to_sym] = if raw.respond_to?(:[])
                                raw[field] || raw[field.to_sym]
                              elsif raw.respond_to?(field.to_sym)
                                raw.send(field.to_sym)
                              end
      end
      
      Controller.new(
        client: self, 
        id: attrs[:id],
        name: attrs[:name],
        model: attrs[:model],
        firmware_version: attrs[:firmware_version],
        encryption_mode: attrs[:encryption_mode],
        encryption_capability: attrs[:encryption_capability],
        controller_type: attrs[:controller_type],
        pci_slot: attrs[:pci_slot],
        status: attrs[:status],
        drives_count: attrs[:drives_count],
        vendor: @vendor, 
        adapter_data: raw
      )
    end
  end
end

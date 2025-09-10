# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'base64'
require 'uri'
require 'json'
require 'colorize'
require 'active_support'
require 'active_support/core_ext'

module Radfish
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class ConnectionError < Error; end
  class NotFoundError < Error; end
  class TimeoutError < Error; end
  class UnsupportedVendorError < Error; end
  
  # Virtual Media specific errors
  class VirtualMediaError < Error; end
  class VirtualMediaNotFoundError < VirtualMediaError; end
  class VirtualMediaConnectionError < VirtualMediaError; end
  class VirtualMediaLicenseError < VirtualMediaError; end
  class VirtualMediaBusyError < VirtualMediaError; end
  
  # Task/Job errors
  class TaskError < Error; end
  class TaskTimeoutError < TaskError; end
  class TaskFailedError < TaskError; end

  module Debuggable
    def debug(message, level = 1, color = :light_cyan)
      return unless respond_to?(:verbosity) && verbosity >= level
      color_method = color.is_a?(Symbol) && String.method_defined?(color) ? color : :to_s
      puts message.send(color_method)
      
      if respond_to?(:verbosity) && verbosity >= 3 && caller.length > 1
        puts "  Called from:".light_yellow
        caller[1..3].each do |call|
          puts "    #{call}".light_yellow
        end
      end
    end
  end

  class << self
    def new(options = {})
      Client.new(options)
    end
    
    def connect(**options, &block)
      Client.connect(**options, &block)
    end

    def detect_vendor(host:, username:, password:, **options)
      VendorDetector.new(host: host, username: username, password: password, **options).detect
    end

    def register_adapter(vendor, adapter_class)
      @adapters ||= {}
      @adapters[vendor.to_s.downcase] = adapter_class
    end

    def get_adapter(vendor)
      @adapters ||= {}
      @adapters[vendor.to_s.downcase]
    end

    def supported_vendors
      @adapters&.keys || []
    end
  end
end

require_relative 'radfish/version'
require_relative 'radfish/http_client'
require_relative 'radfish/core/base_client'
require_relative 'radfish/core/session'
require_relative 'radfish/core/power'
require_relative 'radfish/core/system'
require_relative 'radfish/core/storage'
require_relative 'radfish/core/virtual_media'
require_relative 'radfish/core/boot'
require_relative 'radfish/core/jobs'
require_relative 'radfish/core/utility'
require_relative 'radfish/core/network'
require_relative 'radfish/vendor_detector'
require_relative 'radfish/system_info'
require_relative 'radfish/bmc_info'
require_relative 'radfish/power_info'
require_relative 'radfish/thermal_info'
require_relative 'radfish/pci_info'
require_relative 'radfish/controller'
require_relative 'radfish/volume'
require_relative 'radfish/client'

# Auto-load adapters if available
begin
  require 'radfish/idrac_adapter'
rescue LoadError
  # radfish-idrac gem not installed
end

begin
  require 'radfish/supermicro_adapter'
rescue LoadError
  # radfish-supermicro gem not installed
end

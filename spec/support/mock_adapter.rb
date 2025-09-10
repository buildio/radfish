# frozen_string_literal: true

module Radfish
  class MockAdapter
    include Radfish::Debuggable
    
    attr_accessor :verbosity
    attr_reader :host, :username, :password, :base_url
    
    def initialize(host:, username:, password:, **options)
      @host = host
      @username = username
      @password = password
      @port = options[:port] || 443
      @verify_ssl = options.fetch(:verify_ssl, false)
      @base_url = "https://#{host}:#{@port}"
      @logged_in = false
      @verbosity = options[:verbosity] || 0
    end
    
    def vendor
      'mock'
    end
    
    # Session management
    def login
      @logged_in = true
      true
    end
    
    def logout
      @logged_in = false
      true
    end
    
    def authenticated_request(method, path, **options)
      { status: 'ok' }
    end
    
    # Power management
    def power_status
      'On'
    end
    
    def power_on
      true
    end
    
    def power_off(force: false)
      true
    end
    
    def power_restart(force: false)
      true
    end
    
    def power_cycle
      true
    end
    
    # System information
    def system_info
      Factories.build_system_info if defined?(Factories)
    end
    
    def service_tag
      system_info['ServiceTag'] || system_info['SerialNumber']
    end
    
    def make
      system_info['Manufacturer']
    end
    
    def model
      system_info['Model']
    end
    
    def serial
      system_info['SerialNumber']
    end
    
    # Hardware components
    def cpus
      []
    end
    
    def memory
      []
    end
    
    def nics
      []
    end
    
    def fans
      []
    end
    
    def temperatures
      []
    end
    
    def psus
      []
    end
    
    def power_consumption
      {}
    end
    
    def power_consumption_watts
      0
    end
    
    def system_health
      'OK'
    end
    
    # Virtual Media
    def virtual_media
      []
    end
    
    def virtual_media_status
      [Factories.build_virtual_media_device] if defined?(Factories)
    end
    
    def insert_virtual_media(iso_url, device: nil)
      true
    end
    
    def eject_virtual_media(device: nil)
      true
    end
    
    def unmount_all_media
      true
    end
    
    # Boot configuration
    def boot_options
      []
    end
    
    def set_boot_override(target, persistence: nil, mode: nil, persistent: false)
      true
    end
    
    def boot_to_cd(mode: nil, persistence: nil)
      set_boot_override('Cd', persistence: persistence, mode: mode)
    end
    
    def boot_to_pxe(mode: nil, persistence: nil)
      set_boot_override('Pxe', persistence: persistence, mode: mode)
    end
    
    def boot_to_disk(mode: nil, persistence: nil)
      set_boot_override('Hdd', persistence: persistence, mode: mode)
    end
    
    def boot_to_usb(mode: nil, persistence: nil)
      set_boot_override('Usb', persistence: persistence, mode: mode)
    end
    
    def clear_boot_override
      true
    end
    
    # Storage
    def storage_controllers
      []
    end
    
    def drives(controller_id)
      []
    end
    
    def volumes(controller_id)
      []
    end
    
    # Jobs
    def jobs
      []
    end
    
    def job_status(job_id)
      Factories.build_job_response if defined?(Factories)
    end
    
    # Utility
    def sel_log
      []
    end
    
    def accounts
      []
    end
    
    def sessions
      []
    end
    
    def service_info
      Factories.build_redfish_service_root if defined?(Factories)
    end
  end
  
  # Register the mock adapter for testing
  Radfish.register_adapter('mock', MockAdapter)
  Radfish.register_adapter('supermicro', MockAdapter) unless Radfish.get_adapter('supermicro')
end
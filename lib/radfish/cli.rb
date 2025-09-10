# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'json'
require 'colorize'
require 'radfish'

module Radfish
  class CLI < Thor
    class_option :host, aliases: '-h', desc: 'BMC host/IP address (env: RADFISH_HOST)'
    class_option :username, aliases: '-u', desc: 'BMC username (env: RADFISH_USERNAME)'
    class_option :password, aliases: '-p', desc: 'BMC password (env: RADFISH_PASSWORD)'
    class_option :config, aliases: '-c', desc: 'Config file path'
    class_option :vendor, aliases: '-v', desc: 'Vendor (dell, supermicro, hpe, etc) - auto-detect if not specified (env: RADFISH_VENDOR)'
    class_option :port, type: :numeric, default: 443, desc: 'BMC port (env: RADFISH_PORT)'
    class_option :insecure, type: :boolean, default: true, desc: 'Skip SSL verification'
    class_option :verbose, type: :boolean, default: false, desc: 'Enable verbose output'
    class_option :json, type: :boolean, default: false, desc: 'Output in JSON format'
    
    desc "detect", "Detect the vendor of a BMC"
    def detect
      with_connection(skip_login: true) do |opts|
        vendor = Radfish.detect_vendor(
          host: opts[:host],
          username: opts[:username],
          password: opts[:password],
          port: opts[:port],
          verify_ssl: !opts[:insecure]
        )
        
        output_result({ vendor: vendor }, vendor ? "Detected vendor: #{vendor}" : "Could not detect vendor")
      end
    end
    
    desc "info", "Show BMC and system information"
    def info
      with_client do |client|
        info = {
          vendor: client.vendor_name,
          adapter: client.adapter_class.name,
          features: client.supported_features,
          firmware_version: safe_call { client.get_firmware_version },
          redfish_version: safe_call { client.redfish_version },
          system: safe_call { client.system_info }
        }
        
        if options[:json]
          puts JSON.pretty_generate(info)
        else
          puts "=== BMC Information ===".green
          puts "Vendor: #{info[:vendor]}".cyan
          puts "Adapter: #{info[:adapter]}".cyan
          puts "Firmware: #{info[:firmware_version]}".cyan
          puts "Redfish: #{info[:redfish_version]}".cyan
          puts "Features: #{info[:features].join(', ')}".cyan
          
          if info[:system]
            puts "\n=== System Information ===".green
            info[:system].each do |key, value|
              puts "#{key.to_s.gsub('_', ' ').capitalize}: #{value}".cyan
            end
          end
        end
      end
    end
    
    # Power Commands
    desc "power SUBCOMMAND", "Power management"
    option :force, type: :boolean, default: false, desc: "Force power operation (skip graceful shutdown)"
    def power(subcommand = 'status')
      with_client do |client|
        case subcommand
        when 'status', 'state'
          status = client.power_status
          output_result({ power_status: status }, "Power Status: #{status}", status == 'On' ? :green : :yellow)
        when 'consumption', 'usage', 'watts'
          begin
            watts = client.power_consumption_watts
            output_result({ power_consumption_watts: watts }, "Power Consumption: #{watts}W", :green)
          rescue NotImplementedError
            error "Power consumption not supported for this vendor"
          end
        when 'on'
          result = client.power_on
          output_result({ success: result }, result ? "System powered on" : "Failed to power on")
        when 'off'
          result = client.power_off(force: options[:force])
          mode = options[:force] ? "force" : "graceful"
          output_result({ success: result }, result ? "System powered off (#{mode})" : "Failed to power off")
        when 'force-off'
          result = client.power_off(force: true)
          output_result({ success: result }, result ? "System force powered off" : "Failed to force power off")
        when 'restart', 'reboot'
          result = client.power_restart(force: options[:force])
          mode = options[:force] ? "force" : "graceful"
          output_result({ success: result }, result ? "System restarting (#{mode})" : "Failed to restart")
        when 'force-restart', 'force-reboot'
          result = client.power_restart(force: true)
          output_result({ success: result }, result ? "System force restarting" : "Failed to force restart")
        when 'cycle'
          result = client.power_cycle
          output_result({ success: result }, result ? "Power cycle initiated" : "Failed to power cycle")
        else
          error "Unknown power command: #{subcommand}"
          puts "Available: status, on, off, force-off, restart, force-restart, cycle, consumption"
          puts "Use --force flag with 'off' or 'restart' to skip graceful shutdown"
        end
      end
    end
    
    # System Commands
    desc "system SUBCOMMAND", "System inventory"
    def system(subcommand = 'all')
      with_client do |client|
        case subcommand
        when 'all'
          data = {
            cpus: safe_call { client.cpus },
            memory: safe_call { client.memory },
            nics: safe_call { client.nics },
            fans: safe_call { client.fans },
            temps: safe_call { client.temperatures },
            psus: safe_call { client.psus }
          }
          
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            show_system_component('cpus', data[:cpus])
            show_system_component('memory', data[:memory])
            show_system_component('nics', data[:nics])
            show_system_component('fans', data[:fans])
            show_system_component('temps', data[:temps])
            show_system_component('psus', data[:psus])
          end
        when 'cpus', 'cpu'
          data = client.cpus
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            show_system_component('cpus', data)
          end
        when 'memory', 'mem', 'ram'
          data = client.memory
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            show_system_component('memory', data)
          end
        when 'nics', 'network'
          data = client.nics
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            show_system_component('nics', data)
          end
        when 'fans', 'cooling'
          data = client.fans
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            show_system_component('fans', data)
          end
        when 'temps', 'temperatures', 'thermal'
          data = client.temperatures
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            show_system_component('temps', data)
          end
        when 'psus', 'power-supplies'
          data = client.psus
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            show_system_component('psus', data)
          end
        else
          error "Unknown system command: #{subcommand}"
          puts "Available: all, cpus, memory, nics, fans, temps, psus"
        end
      end
    end
    
    # Virtual Media Commands
    desc "media SUBCOMMAND [URL]", "Virtual media management"
    def media(subcommand = 'status', url = nil)
      with_client do |client|
        case subcommand
        when 'status', 'list'
          media = client.virtual_media_status
          if options[:json]
            puts JSON.pretty_generate(media)
          else
            show_media_status(media)
          end
        when 'mount', 'insert'
          if url.nil?
            error "URL required for mount command"
            return
          end
          result = client.insert_virtual_media(url)
          output_result({ success: result }, result ? "Media mounted: #{url}" : "Failed to mount media")
        when 'unmount', 'eject', 'remove'
          result = client.unmount_all_media
          output_result({ success: result }, result ? "All media unmounted" : "Failed to unmount media")
        when 'boot'
          if url.nil?
            error "URL required for boot command"
            return
          end
          result = client.mount_iso_and_boot(url)
          output_result({ success: result }, result ? "ISO mounted and boot set" : "Failed to mount and boot")
        else
          error "Unknown media command: #{subcommand}"
          puts "Available: status, mount URL, unmount, boot URL"
        end
      end
    end
    
    # Boot Commands
    desc "boot SUBCOMMAND [TARGET]", "Boot configuration"
    option :once, type: :boolean, desc: "Boot override for next boot only"
    option :continuous, type: :boolean, desc: "Boot override until manually cleared"
    option :uefi, type: :boolean, desc: "Use UEFI boot mode"
    option :legacy, type: :boolean, desc: "Use Legacy/BIOS boot mode"
    def boot(subcommand = 'options', target = nil)
      with_client do |client|
        case subcommand
        when 'options', 'status'
          opts = client.boot_options
          if options[:json]
            puts JSON.pretty_generate(opts)
          else
            puts "=== Boot Options ===".green
            puts "Override: #{opts['boot_source_override_enabled']} -> #{opts['boot_source_override_target']}".cyan
            puts "Mode: #{opts['boot_source_override_mode']}".cyan if opts['boot_source_override_mode']
            puts "Allowed: #{opts['allowed_targets']&.join(', ')}".cyan if opts['allowed_targets']
          end
        when 'override', 'set'
          if target.nil?
            error "Target required (pxe, disk, cd, usb, bios)"
            return
          end
          
          # Determine persistence setting
          persistence = if options[:once]
            'Once'
          elsif options[:continuous]
            'Continuous'
          else
            'Once'  # Default to Once
          end
          
          # Determine boot mode
          boot_mode = if options[:uefi]
            'UEFI'
          elsif options[:legacy]
            'Legacy'
          else
            nil  # Don't change if not specified
          end
          
          result = client.set_boot_override(target.capitalize, 
                                           persistence: persistence,
                                           mode: boot_mode)
          
          mode_str = boot_mode ? " in #{boot_mode} mode" : ""
          persist_str = " (#{persistence})"
          output_result({ success: result }, 
                       result ? "Boot override set to #{target}#{mode_str}#{persist_str}" : "Failed to set boot override")
        when 'clear', 'reset'
          result = client.clear_boot_override
          output_result({ success: result }, result ? "Boot override cleared" : "Failed to clear boot override")
        when 'pxe'
          result = set_boot_with_options(client, 'Pxe')
          output_result({ success: result }, result ? "Boot to PXE set" : "Failed to set PXE boot")
        when 'disk', 'hdd'
          result = set_boot_with_options(client, 'Hdd')
          output_result({ success: result }, result ? "Boot to disk set" : "Failed to set disk boot")
        when 'cd', 'dvd'
          result = set_boot_with_options(client, 'Cd')
          output_result({ success: result }, result ? "Boot to CD set" : "Failed to set CD boot")
        when 'usb'
          result = set_boot_with_options(client, 'Usb')
          output_result({ success: result }, result ? "Boot to USB set" : "Failed to set USB boot")
        when 'bios', 'setup'
          result = set_boot_with_options(client, 'BiosSetup')
          output_result({ success: result }, result ? "Boot to BIOS setup set" : "Failed to set BIOS boot")
        when 'config'
          # New subcommand to configure boot settings
          configure_boot_settings(client)
        else
          error "Unknown boot command: #{subcommand}"
          puts "Available: options, set TARGET, clear, pxe, disk, cd, usb, bios, config"
          puts "Options: --once, --continuous, --uefi, --legacy"
        end
      end
    end
    
    # SEL Commands
    desc "sel SUBCOMMAND", "System Event Log management"
    def sel(subcommand = 'show')
      with_client do |client|
        case subcommand
        when 'show', 'list'
          entries = client.sel_log
          limit = 10
          entries = entries.first(limit) if entries.length > limit
          
          if options[:json]
            puts JSON.pretty_generate(entries)
          else
            puts "=== System Event Log (last #{limit}) ===".green
            entries.each do |entry|
              severity_color = case entry['severity']
                              when 'Critical' then :red
                              when 'Warning' then :yellow
                              else :cyan
                              end
              puts "[#{entry['created']}] #{entry['severity']}".send(severity_color)
              puts "  #{entry['message']}"
            end
          end
        when 'clear'
          result = client.clear_sel_log
          output_result({ success: result }, result ? "SEL cleared" : "Failed to clear SEL")
        else
          error "Unknown SEL command: #{subcommand}"
          puts "Available: show, clear"
        end
      end
    end
    
    # Storage Commands
    desc "storage SUBCOMMAND", "Storage information"
    def storage(subcommand = 'summary')
      with_client do |client|
        case subcommand
        when 'summary', 'all'
          data = client.storage_summary
          output_result(data, nil) if options[:json]
        when 'controllers'
          data = client.storage_controllers
          output_result(data, nil) if options[:json]
          unless options[:json]
            puts "=== Storage Controllers ===".green
            data.each do |ctrl|
              puts "#{ctrl['name']} (#{ctrl['id']})".cyan
            end
          end
        when 'drives', 'disks'
          # Get all drives from all controllers
          controllers = client.storage_controllers
          all_drives = []
          
          controllers.each do |controller|
            # Handle different ways the controller ID might be stored
            controller_id = if controller.is_a?(OpenStruct)
                             # For OpenStruct, access the internal table
                             controller.instance_variable_get(:@table)[:"@odata.id"] ||
                             controller.instance_variable_get(:@table)["@odata.id"] ||
                             controller.id
                           elsif controller.respond_to?(:[])
                             # For Hash-like objects
                             controller['@odata.id'] || controller['id']
                           else
                             # For other objects
                             controller.id rescue nil
                           end
            
            if controller_id
              begin
                drives = client.drives(controller_id)
                all_drives.concat(drives) if drives
              rescue => e
                puts "Error fetching drives for controller #{controller['name'] || controller_id}: #{e.message}".yellow if options[:verbose]
              end
            end
          end
          
          if options[:json]
            puts JSON.pretty_generate(all_drives)
          else
            puts "=== Physical Drives ===".green
            if all_drives.empty?
              puts "No drives found".yellow
            else
              all_drives.each do |drive|
                cert_status = drive['certified'] || drive.certified rescue nil
                cert_info = cert_status ? " [Certified: #{cert_status}]" : ""
                capacity = drive['capacity_gb'] || drive.capacity_gb rescue "Unknown"
                status = drive['status'] || drive.status rescue "Unknown"
                name = drive['name'] || drive.name rescue "Unknown"
                puts "#{name}: #{capacity} GB - #{status}#{cert_info}".cyan
              end
            end
          end
        when 'volumes', 'raids'
          # Get all volumes from all controllers
          controllers = client.storage_controllers
          all_volumes = []
          
          controllers.each do |controller|
            # Handle different ways the controller ID might be stored
            controller_id = if controller.is_a?(OpenStruct)
                             # For OpenStruct, access the internal table
                             controller.instance_variable_get(:@table)[:"@odata.id"] ||
                             controller.instance_variable_get(:@table)["@odata.id"] ||
                             controller.id
                           elsif controller.respond_to?(:[])
                             # For Hash-like objects
                             controller['@odata.id'] || controller['id']
                           else
                             # For other objects
                             controller.id rescue nil
                           end
            
            if controller_id
              begin
                volumes = client.volumes(controller_id)
                all_volumes.concat(volumes) if volumes
              rescue => e
                puts "Error fetching volumes for controller #{controller['name'] || controller_id}: #{e.message}".yellow if options[:verbose]
              end
            end
          end
          
          if options[:json]
            puts JSON.pretty_generate(all_volumes)
          else
            puts "=== Volumes ===".green
            if all_volumes.empty?
              puts "No volumes found".yellow
            else
              all_volumes.each do |vol|
                name = vol['name'] || vol.name rescue "Unknown"
                capacity = vol['capacity_gb'] || vol.capacity_gb rescue "Unknown"
                raid_type = vol['raid_type'] || vol.raid_type rescue "Unknown"
                status = vol['status'] || vol.status rescue "Unknown"
                puts "#{name}: #{capacity} GB - #{raid_type} (Status: #{status})".cyan
              end
            end
          end
        else
          error "Unknown storage command: #{subcommand}"
          puts "Available: summary, controllers, drives, volumes"
        end
      end
    end
    
    # Network Commands
    desc "network SUBCOMMAND", "BMC network configuration"
    option :ip, desc: "IP address to set"
    option :mask, desc: "Subnet mask"
    option :gateway, desc: "Gateway address"
    option :dns1, desc: "Primary DNS server"
    option :dns2, desc: "Secondary DNS server"
    option :hostname, desc: "BMC hostname"
    def network(subcommand = 'show')
      with_client do |client|
        case subcommand
        when 'show', 'get', 'status'
          data = client.get_bmc_network
          if options[:json]
            puts JSON.pretty_generate(data)
          else
            puts "=== BMC Network Configuration ===".green
            puts "IP Address:  #{data['ipv4_address']}".cyan
            puts "Subnet Mask: #{data['subnet_mask']}".cyan
            puts "Gateway:     #{data['gateway']}".cyan
            puts "Mode:        #{data['mode']}".cyan
            puts "MAC Address: #{data['mac_address']}".cyan
            puts "Hostname:    #{data['hostname']}".cyan if data['hostname']
            puts "FQDN:        #{data['fqdn']}".cyan if data['fqdn']
            if data['dns_servers'] && !data['dns_servers'].empty?
              puts "DNS Servers: #{data['dns_servers'].join(', ')}".cyan
            end
          end
        when 'set', 'configure'
          if !options[:ip] && !options[:hostname] && !options[:dns1]
            error "Must provide at least --ip, --hostname, or --dns1"
            return
          end
          
          if options[:ip] && !options[:mask]
            error "Must provide --mask when setting --ip"
            return
          end
          
          result = client.set_bmc_network(
            ip_address: options[:ip],
            subnet_mask: options[:mask],
            gateway: options[:gateway],
            dns_primary: options[:dns1],
            dns_secondary: options[:dns2],
            hostname: options[:hostname]
          )
          output_result({ success: result }, result ? "Network configured successfully" : "Failed to configure network")
        when 'dhcp'
          result = client.set_bmc_dhcp
          output_result({ success: result }, result ? "BMC set to DHCP mode" : "Failed to set DHCP mode")
        else
          error "Unknown network command: #{subcommand}"
          puts "Available: show, set, dhcp"
        end
      end
    end
    
    # Config Commands
    desc "config SUBCOMMAND", "Configuration file management"
    def config(subcommand = 'generate')
      case subcommand
      when 'generate', 'create'
        config = {
          'host' => '192.168.1.100',
          'username' => 'admin',
          'password' => 'password',
          'vendor' => 'auto',
          'port' => 443,
          'insecure' => true
        }
        puts YAML.dump(config)
      when 'validate'
        if options[:config]
          validate_config_file(options[:config])
        else
          error "Config file path required (use --config FILE)"
        end
      else
        error "Unknown config command: #{subcommand}"
        puts "Available: generate, validate"
      end
    end
    
    desc "licenses", "Check BMC licenses (Supermicro only)"
    def licenses
      with_client do |client|
        if client.respond_to?(:check_virtual_media_license)
          # Supermicro-specific license check
          license_info = client.check_virtual_media_license
          
          if options[:json]
            puts JSON.pretty_generate(license_info)
          else
            puts "=== License Status ===".green
            
            case license_info[:available]
            when true
              puts "Virtual Media License: #{'Present'.green}"
              puts "Licenses: #{license_info[:licenses].join(', ')}"
            when false
              puts "Virtual Media License: #{'Missing'.red}"
              puts license_info[:message].yellow
            else
              puts "Virtual Media License: #{'Unknown'.yellow}"
              puts license_info[:message].yellow
            end
            
            # Show all licenses if available
            if client.respond_to?(:licenses)
              all_licenses = client.licenses
              if all_licenses.any?
                puts "\n=== All Licenses ===".green
                all_licenses.each do |lic|
                  puts "  #{lic[:name]} (ID: #{lic[:id]})".cyan
                end
              end
            end
          end
        else
          error "License checking not supported for this vendor"
        end
      end
    end
    
    desc "version", "Show radfish version"
    def version
      puts "Radfish #{Radfish::VERSION}"
      puts "Supported vendors: #{Radfish.supported_vendors.join(', ')}" if Radfish.supported_vendors.any?
    end
    
    private
    
    def set_boot_with_options(client, target)
      # Determine persistence setting
      persistence = if options[:once]
        'Once'
      elsif options[:continuous]
        'Continuous'
      else
        'Once'  # Default to Once
      end
      
      # Determine boot mode
      boot_mode = if options[:uefi]
        'UEFI'
      elsif options[:legacy]
        'Legacy'
      else
        nil  # Don't change if not specified
      end
      
      client.set_boot_override(target, persistence: persistence, mode: boot_mode)
    end
    
    def configure_boot_settings(client)
      # Configure just the boot settings without changing target
      persistence = if options[:once]
        'Once'
      elsif options[:continuous]
        'Continuous'
      else
        nil
      end
      
      boot_mode = if options[:uefi]
        'UEFI'
      elsif options[:legacy]
        'Legacy'
      else
        nil
      end
      
      if persistence.nil? && boot_mode.nil?
        error "Specify --once/--continuous and/or --uefi/--legacy"
        return
      end
      
      result = client.configure_boot_settings(persistence: persistence, mode: boot_mode)
      
      settings = []
      settings << "persistence: #{persistence}" if persistence
      settings << "mode: #{boot_mode}" if boot_mode
      
      output_result({ success: result }, 
                   result ? "Boot settings updated (#{settings.join(', ')})" : "Failed to update boot settings")
    end
    
    def with_connection(skip_login: false)
      opts = load_options
      
      missing = []
      missing << 'host' unless opts[:host]
      missing << 'username' unless opts[:username]
      missing << 'password' unless opts[:password]
      
      unless missing.empty?
        if options[:json]
          STDERR.puts JSON.generate({ 
            error: "Missing required options", 
            missing: missing,
            message: "Use --host, --username, --password or specify a config file with --config"
          })
        else
          error "Missing required options: #{missing.join(', ')}"
          error "Use --host, --username, --password or specify a config file with --config"
        end
        exit 1
      end
      
      yield opts
    end
    
    def with_client(&block)
      with_connection do |opts|
        client_opts = {
          host: opts[:host],
          username: opts[:username],
          password: opts[:password],
          port: opts[:port],
          verify_ssl: !opts[:insecure],
          direct_mode: true
        }
        
        client_opts[:vendor] = opts[:vendor] if opts[:vendor]
        
        begin
          client = Radfish::Client.new(**client_opts)
          client.verbosity = 1 if opts[:verbose]
          
          client.login
          yield client
        rescue => e
          error "Error: #{e.message}"
          exit 1
        ensure
          client.logout if client rescue nil
        end
      end
    end
    
    def load_options
      opts = {}
      
      # Load from config file if specified
      if options[:config]
        config_file = File.expand_path(options[:config])
        if File.exist?(config_file)
          config = YAML.load_file(config_file)
          opts = symbolize_keys(config)
        else
          error "Config file not found: #{config_file}"
          exit 1
        end
      end
      
      # Override with command line options
      opts[:host] = options[:host] if options[:host]
      opts[:username] = options[:username] if options[:username]
      opts[:password] = options[:password] if options[:password]
      opts[:vendor] = options[:vendor] if options[:vendor]
      opts[:port] = options[:port] if options[:port]
      opts[:insecure] = options[:insecure] if options.key?(:insecure)
      opts[:verbose] = options[:verbose] if options.key?(:verbose)
      
      # Check environment variables as fallback
      opts[:host] ||= ENV['RADFISH_HOST']
      opts[:username] ||= ENV['RADFISH_USERNAME']
      opts[:password] ||= ENV['RADFISH_PASSWORD']
      opts[:vendor] ||= ENV['RADFISH_VENDOR']
      opts[:port] ||= ENV['RADFISH_PORT'].to_i if ENV['RADFISH_PORT']
      
      opts
    end
    
    def symbolize_keys(hash)
      hash.transform_keys(&:to_sym)
    end
    
    def safe_call
      yield
    rescue => e
      options[:verbose] ? e.message : 'N/A'
    end
    
    def error(message)
      if options[:json]
        STDERR.puts JSON.generate({ error: message })
      else
        STDERR.puts message.red
      end
    end
    
    def success(message)
      puts message.green unless options[:json]
    end
    
    def info_msg(message)
      puts message.cyan unless options[:json]
    end
    
    def output_result(data, message, color = :green)
      if options[:json]
        puts JSON.pretty_generate(data)
      elsif message
        puts message.send(color)
      end
    end
    
    def show_media_status(media_list)
      puts "\n=== Virtual Media Status ===".green
      
      if media_list.nil? || media_list.empty?
        puts "No virtual media devices found".yellow
        return
      end
      
      # Check if any media is inserted
      has_mounted_media = media_list.any? { |m| m[:inserted] || m[:image] }
      
      media_list.each do |media|
        # Display device name with ID if the name is generic
        device_display = media[:name] || media[:device] || 'Unknown'
        puts "\nDevice: #{device_display}".cyan
        
        # Show media types if available
        puts "  Media Types: #{media[:media_types]&.join(', ')}" if media[:media_types]
        
        # Check for CD/DVD support for boot guidance
        supports_cd = media[:media_types]&.any? { |t| t.upcase.include?('CD') || t.upcase.include?('DVD') }
        
        if media[:inserted] || media[:image]
          # Determine actual status based on image presence
          if media[:image] && !media[:image].empty? && media[:image] != "http://0.0.0.0/dummy.iso"
            # Check connection status
            if media[:connected_via]
              case media[:connected_via]
              when "NotConnected"
                puts "  Status: #{'NOT CONNECTED'.red} (ISO won't boot)"
                puts "  Image: #{media[:image]}"
                puts "  Connection: #{'Not Connected - Media will NOT boot!'.red}"
              when "URI"
                puts "  Status: #{'Connected'.green} (Ready to boot)"
                puts "  Image: #{media[:image]}"
                puts "  Connection: #{'Active via URI'.green}"
              when "Applet"
                puts "  Status: #{'Connected'.green} (Ready to boot)"
                puts "  Image: #{media[:image]}"
                puts "  Connection: Active via Applet"
              else
                puts "  Status: Unknown"
                puts "  Image: #{media[:image]}"
                puts "  Connection: #{media[:connected_via]}"
              end
            else
              puts "  Image: #{media[:image]}"
            end
            
            if supports_cd
              puts "  Boot Command: radfish boot cd".light_blue
            end
          else
            puts "  Status: #{'Empty'.yellow}"
          end
        else
          puts "  Status: #{'Empty'.yellow}"
        end
      end
      
      if has_mounted_media
        puts "\nTo boot from virtual media:".green
        puts "  1. radfish boot cd         # Set boot to CD/DVD".cyan
        puts "  2. radfish power restart   # Restart the server".cyan
      end
    end
    
    def show_system_component(type, data)
      return unless data
      
      case type
      when 'cpus'
        puts "\n=== CPUs ===".green
        data.each do |cpu|
          puts "#{cpu['socket']}: #{cpu['manufacturer']} #{cpu['model']}".cyan
          puts "  Cores: #{cpu['cores']}, Threads: #{cpu['threads']}, Speed: #{cpu['speed_mhz']} MHz"
        end
      when 'memory'
        puts "\n=== Memory ===".green
        total_gb = data.sum { |m| m["capacity_bytes"] || 0 } / (1024.0 ** 3)
        puts "Total: #{total_gb.round(2)} GB".cyan
        data.each do |dimm|
          next if dimm["capacity_bytes"].nil? || dimm["capacity_bytes"] == 0
          capacity_gb = dimm["capacity_bytes"] / (1024.0 ** 3)
          puts "#{dimm['name']}: #{capacity_gb.round(2)} GB @ #{dimm['speed_mhz']} MHz"
        end
      when 'nics'
        puts "\n=== Network Interfaces ===".green
        data.each do |nic|
          puts "#{nic['name']}: #{nic['mac']}".cyan
          puts "  Speed: #{nic['speed_mbps']} Mbps, Link: #{nic['link_status']}"
        end
      when 'fans'
        puts "\n=== Fans ===".green
        data.each do |fan|
          status_color = fan['status'] == 'OK' ? :green : :red
          puts "#{fan['name']}: #{fan['rpm']} RPM - #{fan['status']}".send(status_color)
        end
      when 'temps'
        puts "\n=== Temperature Sensors ===".green
        data.each do |temp|
          next unless temp['reading_celsius']
          status_color = temp['status'] == 'OK' ? :green : :red
          puts "#{temp['name']}: #{temp['reading_celsius']}°C".send(status_color)
        end
      when 'psus'
        puts "\n=== Power Supplies ===".green
        data.each do |psu|
          status_color = psu['status'] == 'OK' ? :green : :red
          voltage_info = psu['voltage'] ? "#{psu['voltage']}V (#{psu['voltage_human'] || 'Unknown'})" : ""
          puts "#{psu['name']}: #{voltage_info} #{psu['watts']}W - #{psu['status']}".send(status_color)
          puts "  Model: #{psu['model']}" if psu['model']
          puts "  Serial: #{psu['serial']}" if psu['serial']
        end
      end
    end
    
    def validate_config_file(file)
      file = File.expand_path(file)
      if File.exist?(file)
        begin
          config = YAML.load_file(file)
          required = ['host', 'username', 'password']
          missing = required - config.keys
          
          if missing.empty?
            success "Config file is valid"
          else
            error "Config file missing required fields: #{missing.join(', ')}"
          end
        rescue => e
          error "Invalid config file: #{e.message}"
        end
      else
        error "Config file not found: #{file}"
      end
    end
  end
end
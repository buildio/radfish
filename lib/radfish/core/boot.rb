# frozen_string_literal: true

module Radfish
  module Core
    module Boot
      def boot_config
        raise NotImplementedError, "Adapter must implement #boot_config"
      end
      
      def set_boot_override(target, persistence: nil, mode: nil)
        raise NotImplementedError, "Adapter must implement #set_boot_override"
      end
      
      def clear_boot_override
        raise NotImplementedError, "Adapter must implement #clear_boot_override"
      end
      
      def set_boot_order(devices)
        raise NotImplementedError, "Adapter must implement #set_boot_order"
      end
      
      def get_boot_devices
        raise NotImplementedError, "Adapter must implement #get_boot_devices"
      end
      
      def boot_to_pxe
        raise NotImplementedError, "Adapter must implement #boot_to_pxe"
      end
      
      def boot_to_disk
        raise NotImplementedError, "Adapter must implement #boot_to_disk"
      end
      
      def boot_to_cd
        raise NotImplementedError, "Adapter must implement #boot_to_cd"
      end

      # Convenience: one-time boot to the virtual CD. Default delegates to the adapter's standard
      # Redfish boot override (boot_to_cd, which defaults to a one-time override). Adapters with a
      # more reliable vendor path (e.g. Dell's SCP ServerBoot) override this. `reboot:` is accepted
      # for signature parity with those overrides; the default does not reboot -- the caller cycles
      # power (the app's install_os! does).
      def set_one_time_cd_boot(reboot: false)
        boot_to_cd
      end

      def boot_to_usb
        raise NotImplementedError, "Adapter must implement #boot_to_usb"
      end
      
      def boot_to_bios_setup
        raise NotImplementedError, "Adapter must implement #boot_to_bios_setup"
      end
    end
  end
end

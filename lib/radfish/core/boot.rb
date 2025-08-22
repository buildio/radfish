# frozen_string_literal: true

module Radfish
  module Core
    module Boot
      def boot_options
        raise NotImplementedError, "Adapter must implement #boot_options"
      end
      
      def set_boot_override(target, persistent: false)
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
      
      def boot_to_usb
        raise NotImplementedError, "Adapter must implement #boot_to_usb"
      end
      
      def boot_to_bios_setup
        raise NotImplementedError, "Adapter must implement #boot_to_bios_setup"
      end
    end
  end
end
# frozen_string_literal: true

module Radfish
  module Core
    module VirtualMedia
      def virtual_media
        raise NotImplementedError, "Adapter must implement #virtual_media"
      end
      
      def insert_virtual_media(iso_url, device: nil)
        raise NotImplementedError, "Adapter must implement #insert_virtual_media"
      end
      
      def eject_virtual_media(device: nil)
        raise NotImplementedError, "Adapter must implement #eject_virtual_media"
      end
      
      def virtual_media_status
        raise NotImplementedError, "Adapter must implement #virtual_media_status"
      end
      
      def mount_iso_and_boot(iso_url, device: nil)
        raise NotImplementedError, "Adapter must implement #mount_iso_and_boot"
      end
      
      def unmount_all_media
        raise NotImplementedError, "Adapter must implement #unmount_all_media"
      end
    end
  end
end
# frozen_string_literal: true

module Radfish
  module Core
    module Storage
      def storage_controllers
        raise NotImplementedError, "Adapter must implement #storage_controllers"
      end
      
      def drives(controller)
        raise NotImplementedError, "Adapter must implement #drives(controller)"
      end
      
      def volumes(controller)
        raise NotImplementedError, "Adapter must implement #volumes(controller)"
      end
      
      def storage_summary
        raise NotImplementedError, "Adapter must implement #storage_summary"
      end

      # Given a Volume, return its physical drive objects
      def volume_drives(volume)
        raise NotImplementedError, "Adapter must implement #volume_drives(volume)"
      end

    end
  end
end

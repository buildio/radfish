# frozen_string_literal: true

module Radfish
  module Core
    module Storage
      def storage_controllers
        raise NotImplementedError, "Adapter must implement #storage_controllers"
      end
      
      def drives(controller_id)
        raise NotImplementedError, "Adapter must implement #drives(controller_id)"
      end
      
      def volumes(controller_id)
        raise NotImplementedError, "Adapter must implement #volumes(controller_id)"
      end
      
      def storage_summary
        raise NotImplementedError, "Adapter must implement #storage_summary"
      end
    end
  end
end
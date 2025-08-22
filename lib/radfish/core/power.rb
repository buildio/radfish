# frozen_string_literal: true

module Radfish
  module Core
    module Power
      def power_status
        raise NotImplementedError, "Adapter must implement #power_status"
      end
      
      def power_on
        raise NotImplementedError, "Adapter must implement #power_on"
      end
      
      def power_off
        raise NotImplementedError, "Adapter must implement #power_off"
      end
      
      def power_restart
        raise NotImplementedError, "Adapter must implement #power_restart"
      end
      
      def power_cycle
        raise NotImplementedError, "Adapter must implement #power_cycle"
      end
      
      def reset_type_allowed
        raise NotImplementedError, "Adapter must implement #reset_type_allowed"
      end
    end
  end
end
# frozen_string_literal: true

module Radfish
  module Core
    module System
      def system_info
        raise NotImplementedError, "Adapter must implement #system_info"
      end
      
      def cpus
        raise NotImplementedError, "Adapter must implement #cpus"
      end
      
      def memory
        raise NotImplementedError, "Adapter must implement #memory"
      end
      
      def nics
        raise NotImplementedError, "Adapter must implement #nics"
      end
      
      def fans
        raise NotImplementedError, "Adapter must implement #fans"
      end
      
      def temperatures
        raise NotImplementedError, "Adapter must implement #temperatures"
      end
      
      def psus
        raise NotImplementedError, "Adapter must implement #psus"
      end
      
      def power_consumption
        raise NotImplementedError, "Adapter must implement #power_consumption"
      end
      
      def power_consumption_watts
        raise NotImplementedError, "Adapter must implement #power_consumption_watts"
      end
    end
  end
end
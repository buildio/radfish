# frozen_string_literal: true

module Radfish
  module Core
    module Network
      def get_bmc_network
        raise NotImplementedError, "Adapter must implement #get_bmc_network"
      end
      
      def set_bmc_network(ip_address: nil, subnet_mask: nil, gateway: nil, 
                          dns_primary: nil, dns_secondary: nil, hostname: nil, 
                          dhcp: false)
        raise NotImplementedError, "Adapter must implement #set_bmc_network"
      end
      
      def set_bmc_dhcp
        # Convenience method that calls set_bmc_network with dhcp: true
        set_bmc_network(dhcp: true)
      end
    end
  end
end
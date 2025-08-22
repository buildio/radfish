# frozen_string_literal: true

module Radfish
  module Core
    module Utility
      def sel_log
        raise NotImplementedError, "Adapter must implement #sel_log"
      end
      
      def clear_sel_log
        raise NotImplementedError, "Adapter must implement #clear_sel_log"
      end
      
      def sel_summary(limit: 10)
        raise NotImplementedError, "Adapter must implement #sel_summary"
      end
      
      def accounts
        raise NotImplementedError, "Adapter must implement #accounts"
      end
      
      def create_account(username:, password:, role: "Administrator")
        raise NotImplementedError, "Adapter must implement #create_account"
      end
      
      def delete_account(username)
        raise NotImplementedError, "Adapter must implement #delete_account"
      end
      
      def update_account_password(username:, new_password:)
        raise NotImplementedError, "Adapter must implement #update_account_password"
      end
      
      def sessions
        raise NotImplementedError, "Adapter must implement #sessions"
      end
      
      def service_info
        raise NotImplementedError, "Adapter must implement #service_info"
      end
      
      def get_firmware_version
        raise NotImplementedError, "Adapter must implement #get_firmware_version"
      end
    end
  end
end
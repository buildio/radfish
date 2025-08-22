# frozen_string_literal: true

module Radfish
  module CLI
    module Base
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def cli_instance
          @cli_instance ||= Radfish::CLI.new
        end
      end
      
      def with_client(&block)
        self.class.cli_instance.send(:with_client, &block)
      end
      
      def success(message)
        self.class.cli_instance.send(:success, message)
      end
      
      def error(message)
        self.class.cli_instance.send(:error, message)
      end
      
      def info_msg(message)
        self.class.cli_instance.send(:info_msg, message)
      end
      
      def safe_call
        yield
      rescue => e
        parent_options[:verbose] ? e.message : nil
      end
    end
  end
end
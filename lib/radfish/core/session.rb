# frozen_string_literal: true

module Radfish
  module Core
    class Session
      include Debuggable
      
      attr_reader :client, :x_auth_token, :session_id
      
      def initialize(client)
        @client = client
        @x_auth_token = nil
        @session_id = nil
      end
      
      def connection
        @connection ||= Faraday.new(url: client.base_url, ssl: { verify: client.verify_ssl }) do |faraday|
          faraday.request :url_encoded
          faraday.adapter Faraday.default_adapter
        end
      end
      
      def create
        debug "Creating Redfish session for #{client.host}", 1
        
        payload = {
          UserName: client.username,
          Password: client.password
        }.to_json
        
        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
        headers['Host'] = client.host_header if client.host_header
        
        begin
          response = connection.post('/redfish/v1/SessionService/Sessions', payload, headers)
          
          if response.status == 201
            @x_auth_token = response.headers['x-auth-token']
            
            if response.headers['location']
              @session_id = response.headers['location'].split('/').last
            end
            
            begin
              body = JSON.parse(response.body)
              @session_id ||= body["Id"] if body.is_a?(Hash)
            rescue JSON::ParserError
            end
            
            debug "Session created successfully. Token: #{@x_auth_token ? @x_auth_token[0..10] + '...' : 'nil'}", 1, :green
            return true
          else
            debug "Failed to create session. Status: #{response.status}", 1, :red
            debug "Response: #{response.body}", 2
            return false
          end
        rescue Faraday::Error => e
          debug "Connection error creating session: #{e.message}", 1, :red
          return false
        end
      end
      
      def delete
        return unless @x_auth_token && @session_id
        
        debug "Deleting session #{@session_id}", 1
        
        headers = {
          'X-Auth-Token' => @x_auth_token,
          'Accept' => 'application/json'
        }
        headers['Host'] = client.host_header if client.host_header
        
        begin
          response = connection.delete("/redfish/v1/SessionService/Sessions/#{@session_id}", nil, headers)
          
          if response.status == 204 || response.status == 200
            debug "Session deleted successfully", 1, :green
            @x_auth_token = nil
            @session_id = nil
            return true
          else
            debug "Failed to delete session. Status: #{response.status}", 1, :yellow
            return false
          end
        rescue Faraday::Error => e
          debug "Error deleting session: #{e.message}", 1, :yellow
          return false
        end
      end
      
      def valid?
        return false unless @x_auth_token
        
        headers = {
          'X-Auth-Token' => @x_auth_token,
          'Accept' => 'application/json'
        }
        headers['Host'] = client.host_header if client.host_header
        
        begin
          response = connection.get("/redfish/v1/SessionService/Sessions/#{@session_id}", nil, headers)
          response.status == 200
        rescue
          false
        end
      end
      
      private
      
      def verbosity
        client.verbosity
      end
    end
  end
end
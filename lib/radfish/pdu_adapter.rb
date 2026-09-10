# frozen_string_literal: true

require 'json'

module Radfish
  # Generic DMTF Redfish PowerDistribution adapter. PDU identity is standard Redfish,
  # so one adapter serves every brand; it is registered under each PDU vendor name at
  # the bottom of this file. PDUs authenticate with HTTP Basic (no Redfish
  # SessionService), so login/logout are no-ops and every request carries the
  # credentials through the shared HttpClient's basic-auth path.
  class PduAdapter < Core::BaseClient
    POWER_DISTRIBUTION_PATH = '/redfish/v1/PowerDistribution/1'

    # Brand mapping shared with VendorDetector: match Manufacturer/Oem/Model text to a
    # registered adapter key. Order does not matter; the patterns do not overlap.
    PDU_VENDOR_MAP = {
      /apc|american power|schneider/i => 'apc',
      /panduit/i => 'panduit',
      /vertiv|geist|liebert|emerson/i => 'vertiv',
      /server\s*tech|sentry/i => 'servertech',
      /raritan|legrand/i => 'raritan',
      /eaton/i => 'eaton_redfish'
    }.freeze

    # Map a parsed PowerDistribution resource to a registered PDU vendor key, or nil
    # when nothing matches (the caller falls back to 'generic_pdu').
    def self.vendor_from(data)
      return nil unless data.is_a?(Hash)

      oem_key = data['Oem'].is_a?(Hash) ? data['Oem'].keys.first : nil
      haystack = [data['Manufacturer'], oem_key, data['Model']].compact.join(' ')
      return nil if haystack.empty?

      PDU_VENDOR_MAP.each { |pattern, name| return name if haystack.match?(pattern) }
      nil
    end

    # Does a parsed resource look like a Redfish PowerDistribution (rack PDU/rack
    # switch etc.)? Used by detection to accept a body when the brand is unknown.
    def self.power_distribution?(data)
      return false unless data.is_a?(Hash)

      data.key?('EquipmentType') || data.key?('Outlets') || data.key?('PartNumber')
    end

    def vendor
      'generic_pdu'
    end

    # Basic-auth PDU: no session to open or close.
    def login
      true
    end

    def logout
      true
    end

    # Every request is a Basic-auth GET/POST through the HttpClient; no X-Auth-Token.
    def authenticated_request(method, path, **options)
      http_client.send(method, path, **options)
    end

    # Compact identity for the PowerDistribution resource. `raw` carries the full parsed
    # resource so callers can read OEM electrical fields (Voltage, PhaseType, KVARating,
    # BreakerRating, TotalWatts, TotalVA, Load, ...) without a second HTTP request.
    def power_distribution_info
      data = fetch_power_distribution
      {
        vendor: self.class.vendor_from(data) || 'generic_pdu',
        manufacturer: data['Manufacturer'],
        model: data['Model'] || data['PartNumber'],
        part_number: data['PartNumber'],
        serial: data['SerialNumber'] || data['Serial'],
        serial_number: data['SerialNumber'] || data['Serial'],
        firmware_version: data['FirmwareVersion'] || data['FWVersion'],
        equipment_type: data['EquipmentType'],
        raw: data
      }
    end

    private

    def fetch_power_distribution
      response = http_get(POWER_DISTRIBUTION_PATH)
      unless response.status.between?(200, 299)
        raise Radfish::Error, "Failed to fetch PowerDistribution: HTTP #{response.status}"
      end

      JSON.parse(response.body)
    end
  end

  # One generic adapter, registered under every PDU brand. VendorDetector maps a
  # PowerDistribution body to one of these keys, or to 'generic_pdu' when the brand is
  # unknown; the Client then instantiates this same class for all of them.
  %w[generic_pdu apc panduit vertiv servertech raritan eaton_redfish].each do |name|
    register_adapter(name, PduAdapter)
  end
end

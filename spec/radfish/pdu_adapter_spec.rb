# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Radfish::PduAdapter do
  subject(:adapter) do
    described_class.new(host: 'pdu.example', username: 'admin', password: 'secret', verify_ssl: false)
  end

  let(:http) { adapter.instance_variable_get(:@http_client) }

  # Representative APC (Schneider) rack PDU PowerDistribution resource, with OEM
  # electrical fields the compact identity hash does not surface but `raw` must carry.
  let(:apc_body) do
    {
      '@odata.id' => '/redfish/v1/PowerDistribution/1',
      'Id' => '1',
      'EquipmentType' => 'RackPDU',
      'Manufacturer' => 'APC by Schneider Electric',
      'Model' => 'AP8853',
      'PartNumber' => 'AP8853',
      'SerialNumber' => '5A1834E00021',
      'FirmwareVersion' => 'v6.8.2',
      'Voltage' => { 'Reading' => 208.0 },
      'PhaseType' => 'ThreePhase',
      'Outlets' => { '@odata.id' => '/redfish/v1/PowerDistribution/1/Outlets' }
    }
  end

  def stub_pdu(status:, body:)
    allow(http).to receive(:get)
      .with('/redfish/v1/PowerDistribution/1')
      .and_return(double('response', status: status, body: body))
  end

  describe '#power_distribution_info' do
    it 'returns the compact identity hash from an APC PowerDistribution resource' do
      stub_pdu(status: 200, body: apc_body.to_json)
      info = adapter.power_distribution_info

      expect(info[:vendor]).to eq('apc')
      expect(info[:manufacturer]).to eq('APC by Schneider Electric')
      expect(info[:model]).to eq('AP8853')
      expect(info[:part_number]).to eq('AP8853')
      expect(info[:serial]).to eq('5A1834E00021')
      expect(info[:serial_number]).to eq('5A1834E00021')
      expect(info[:firmware_version]).to eq('v6.8.2')
      expect(info[:equipment_type]).to eq('RackPDU')
    end

    it 'carries the full parsed resource in :raw for OEM electrical fields' do
      stub_pdu(status: 200, body: apc_body.to_json)
      raw = adapter.power_distribution_info[:raw]

      expect(raw).to be_a(Hash)
      expect(raw['Voltage']['Reading']).to eq(208.0)
      expect(raw['PhaseType']).to eq('ThreePhase')
      expect(raw['Outlets']['@odata.id']).to eq('/redfish/v1/PowerDistribution/1/Outlets')
    end

    it 'falls back to Serial and FWVersion when the modern keys are absent' do
      body = {
        'EquipmentType' => 'RackPDU',
        'Manufacturer' => 'Panduit',
        'PartNumber' => 'P08G02M',
        'Serial' => 'PANSER123',
        'FWVersion' => '3.5.0'
      }
      stub_pdu(status: 200, body: body.to_json)
      info = adapter.power_distribution_info

      expect(info[:vendor]).to eq('panduit')
      expect(info[:model]).to eq('P08G02M') # Model absent -> PartNumber
      expect(info[:serial]).to eq('PANSER123')
      expect(info[:serial_number]).to eq('PANSER123')
      expect(info[:firmware_version]).to eq('3.5.0')
    end

    it 'raises Radfish::Error when the resource is not reachable' do
      stub_pdu(status: 404, body: '')
      expect { adapter.power_distribution_info }.to raise_error(Radfish::Error, /HTTP 404/)
    end
  end

  describe 'basic-auth session behaviour' do
    it 'treats login and logout as no-ops that succeed' do
      expect(adapter.login).to be(true)
      expect(adapter.logout).to be(true)
    end

    it 'reports a generic PDU vendor' do
      expect(adapter.vendor).to eq('generic_pdu')
    end
  end

  describe 'adapter registration' do
    it 'registers the one generic class under every PDU brand' do
      %w[generic_pdu apc panduit vertiv servertech raritan eaton_redfish].each do |name|
        expect(Radfish.get_adapter(name)).to eq(described_class)
      end
    end
  end
end

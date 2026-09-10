# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Radfish::VendorDetector, 'PDU detection' do
  # Build a detector whose HTTP client answers the service root and the
  # PowerDistribution probe from the given bodies (any other path -> 404).
  def detector_for(root:, pdu: nil)
    detector = described_class.new(host: 'dev.example', username: 'u', password: 'p')
    http = detector.instance_variable_get(:@http_client)
    allow(http).to receive(:get) do |path, **_opts|
      body = case path
             when '/redfish/v1' then root
             when '/redfish/v1/PowerDistribution/1' then pdu
             end
      if body
        double('response', status: 200, body: body.to_json)
      else
        double('response', status: 404, body: '')
      end
    end
    detector
  end

  # A service root with no server-vendor clues, so detection falls through to the PDU probe.
  let(:bare_root) { { '@odata.id' => '/redfish/v1', 'RedfishVersion' => '1.13.0' } }

  it "maps an APC PowerDistribution body to 'apc'" do
    pdu = { 'EquipmentType' => 'RackPDU', 'Manufacturer' => 'APC by Schneider Electric',
            'PartNumber' => 'AP8853', 'Outlets' => {} }
    expect(detector_for(root: bare_root, pdu: pdu).detect).to eq('apc')
  end

  it "maps a Panduit PowerDistribution body to 'panduit'" do
    pdu = { 'EquipmentType' => 'RackPDU', 'Manufacturer' => 'Panduit', 'PartNumber' => 'P08G02M' }
    expect(detector_for(root: bare_root, pdu: pdu).detect).to eq('panduit')
  end

  it "maps an unknown-brand PowerDistribution body to 'generic_pdu'" do
    pdu = { 'EquipmentType' => 'RackPDU', 'Manufacturer' => 'Acme Rack Systems', 'PartNumber' => 'ACME-1' }
    expect(detector_for(root: bare_root, pdu: pdu).detect).to eq('generic_pdu')
  end

  it "returns 'generic' when there is no PowerDistribution resource (no regression)" do
    expect(detector_for(root: bare_root, pdu: nil).detect).to eq('generic')
  end

  it "still detects a Dell Systems root as 'dell' without probing for a PDU" do
    dell_root = { '@odata.id' => '/redfish/v1', 'Oem' => { 'Dell' => { 'FirmwareVersion' => '2.86.86.86' } } }
    detector = detector_for(root: dell_root, pdu: nil)
    http = detector.instance_variable_get(:@http_client)
    expect(detector.detect).to eq('dell')
    # PDU detection must never run once a server vendor is identified.
    expect(http).not_to have_received(:get).with('/redfish/v1/PowerDistribution/1')
  end
end

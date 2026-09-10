# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Radfish::PowerDistributionInfo do
  let(:info_hash) do
    {
      vendor: 'panduit',
      manufacturer: 'Panduit',
      model: 'P08G02M',
      part_number: 'P08G02M',
      serial: 'PANSER123',
      serial_number: 'PANSER123',
      firmware_version: '3.5.0',
      equipment_type: 'RackPDU',
      raw: { 'TotalWatts' => 420, 'Voltage' => { 'Reading' => 208.0 } }
    }
  end

  let(:adapter) { double('adapter') }
  let(:client) { double('client', adapter: adapter) }
  subject(:facade) { described_class.new(client) }

  it 'exposes each field of the adapter hash through a reader' do
    allow(adapter).to receive(:power_distribution_info).and_return(info_hash)

    expect(facade.vendor).to eq('panduit')
    expect(facade.manufacturer).to eq('Panduit')
    expect(facade.model).to eq('P08G02M')
    expect(facade.part_number).to eq('P08G02M')
    expect(facade.serial).to eq('PANSER123')
    expect(facade.serial_number).to eq('PANSER123')
    expect(facade.firmware_version).to eq('3.5.0')
    expect(facade.equipment_type).to eq('RackPDU')
    expect(facade.raw['TotalWatts']).to eq(420)
  end

  it 'memoizes to_h so the adapter is asked exactly once' do
    expect(adapter).to receive(:power_distribution_info).once.and_return(info_hash)

    facade.to_h
    facade.to_h
    expect(facade.vendor).to eq('panduit')
    expect(facade.raw['Voltage']['Reading']).to eq(208.0)
  end
end

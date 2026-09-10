require 'spec_helper'
require 'radfish/cli'
require 'stringio'

RSpec.describe Radfish::CLI, 'verbosity and output' do
  let(:cli) { described_class.new }
  let(:mock_client) { double('Radfish::Client') }

  def capture
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end

  def base_options(extra = {})
    { host: 'bmc.example.com', username: 'root', password: 'pw',
      port: 443, insecure: true, json: false, verbose: false }.merge(extra)
  end

  before do
    allow(Radfish::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:verbosity=)
    allow(mock_client).to receive(:login).and_return(true)
    allow(mock_client).to receive(:logout).and_return(true)
  end

  describe '#storage' do
    let(:summary) do
      { controller_count: 1,
        controllers: [{ name: 'RAID', drive_count: 2, volume_count: 1 }] }
    end

    before { allow(mock_client).to receive(:storage_summary).and_return(summary) }

    # The block takes a second argument now, so it must not be called `options`:
    # that would shadow Thor's #options for the whole block.
    it 'still honours --json' do
      cli.options = base_options(json: true)

      output = capture { cli.storage('summary') }

      expect(JSON.parse(output)).to include('controller_count' => 1)
    end

    it 'prints the human summary without --json' do
      cli.options = base_options

      output = capture { cli.storage('summary') }

      expect(output).to include('Storage Summary')
    end
  end

  describe 'verbosity' do
    it 'is 0 by default' do
      cli.options = base_options
      expect(cli.send(:load_options)[:verbosity]).to eq(0)
    end

    it 'is 1 with --verbose' do
      cli.options = base_options(verbose: true)
      expect(cli.send(:load_options)[:verbosity]).to eq(1)
    end

    it 'takes the level from --debug' do
      cli.options = base_options(debug: 3)
      expect(cli.send(:load_options)[:verbosity]).to eq(3)
    end

    it 'lets --debug win over --verbose' do
      cli.options = base_options(verbose: true, debug: 2)
      expect(cli.send(:load_options)[:verbosity]).to eq(2)
    end

    it 'reaches the client, which detects the vendor in its constructor' do
      captured = nil
      allow(Radfish::Client).to receive(:new) { |**kw| captured = kw; mock_client }
      cli.options = base_options(verbose: true)

      cli.send(:with_client) { |_client, _opts| nil }

      expect(captured[:verbosity]).to eq(1)
    end
  end

  describe 'the --debug class option' do
    it 'defaults to level 2 when given without a value' do
      option = described_class.class_options[:debug]
      expect(option.lazy_default).to eq(2)
    end
  end
end

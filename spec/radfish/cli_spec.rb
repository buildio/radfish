require 'spec_helper'
require 'radfish/cli'

RSpec.describe Radfish::CLI do
  let(:cli) { described_class.new }
  let(:host) { '192.168.1.100' }
  let(:username) { 'admin' }
  let(:password) { 'password' }
  
  before do
    # Prevent actual network calls
    allow_any_instance_of(Radfish::Client).to receive(:login).and_return(true)
    allow_any_instance_of(Radfish::Client).to receive(:logout).and_return(true)
  end

  describe '#version' do
    it 'displays the version' do
      expect { cli.version }.to output(/Radfish \d+\.\d+\.\d+/).to_stdout
    end
  end

  describe '#detect' do
    context 'with valid credentials' do
      before do
        allow(Radfish).to receive(:detect_vendor).and_return('supermicro')
        cli.options = { 
          host: host, 
          username: username, 
          password: password,
          json: false 
        }
      end

      it 'detects the vendor' do
        expect { cli.detect }.to output(/Detected vendor: supermicro/).to_stdout
      end
    end

    context 'with JSON output' do
      before do
        allow(Radfish).to receive(:detect_vendor).and_return('supermicro')
        cli.options = { 
          host: host, 
          username: username, 
          password: password,
          json: true 
        }
      end

      it 'outputs JSON format' do
        expect { cli.detect }.to output(/"vendor":\s*"supermicro"/).to_stdout
      end
    end
  end

  describe '#power' do
    let(:mock_client) { double('Radfish::Client') }
    
    before do
      allow(Radfish::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:login).and_return(true)
      allow(mock_client).to receive(:logout).and_return(true)
      cli.options = { 
        host: host, 
        username: username, 
        password: password,
        json: false 
      }
    end

    context 'status command' do
      it 'shows power status' do
        allow(mock_client).to receive(:power_status).and_return('On')
        expect { cli.power('status') }.to output(/Power Status: On/).to_stdout
      end
    end

    context 'on command' do
      it 'powers on the system' do
        allow(mock_client).to receive(:power_on).and_return(true)
        expect { cli.power('on') }.to output(/System powered on/).to_stdout
      end
    end

    context 'off command' do
      it 'powers off the system gracefully' do
        allow(mock_client).to receive(:power_off).with(force: nil).and_return(true)
        expect { cli.power('off') }.to output(/System powered off \(graceful\)/).to_stdout
      end

      it 'force powers off with --force flag' do
        cli.options[:force] = true
        allow(mock_client).to receive(:power_off).with(force: true).and_return(true)
        expect { cli.power('off') }.to output(/System powered off \(force\)/).to_stdout
      end
    end
  end

  describe '#media' do
    let(:mock_client) { double('Radfish::Client') }
    
    before do
      allow(Radfish::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:login).and_return(true)
      allow(mock_client).to receive(:logout).and_return(true)
      cli.options = { 
        host: host, 
        username: username, 
        password: password,
        json: false 
      }
    end

    context 'status command' do
      it 'shows virtual media status' do
        media_data = [
          {
            device: 'VirtualMedia1',
            name: 'Virtual Removable Media',
            inserted: false,
            image: nil,
            connected_via: 'NotConnected',
            media_types: ['CD', 'DVD']
          }
        ]
        allow(mock_client).to receive(:virtual_media_status).and_return(media_data)
        expect { cli.media('status') }.to output(/Virtual Media Status/).to_stdout
      end
    end

    context 'mount command' do
      it 'mounts an ISO' do
        iso_url = 'http://example.com/test.iso'
        allow(mock_client).to receive(:insert_virtual_media).with(iso_url).and_return(true)
        expect { cli.media('mount', iso_url) }.to output(/Media mounted/).to_stdout
      end

    end

    context 'unmount command' do
      it 'unmounts all media' do
        allow(mock_client).to receive(:unmount_all_media).and_return(true)
        expect { cli.media('unmount') }.to output(/All media unmounted/).to_stdout
      end
    end
  end

  describe '#boot' do
    let(:mock_client) { double('Radfish::Client') }
    
    before do
      allow(Radfish::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:login).and_return(true)
      allow(mock_client).to receive(:logout).and_return(true)
      cli.options = { 
        host: host, 
        username: username, 
        password: password,
        json: false 
      }
    end

    context 'with boot mode options' do
      it 'sets boot to CD with UEFI mode' do
        cli.options[:uefi] = true
        allow(mock_client).to receive(:set_boot_override)
          .with('Cd', persistence: 'Once', mode: 'UEFI')
          .and_return(true)
        expect { cli.boot('cd') }.to output(/Boot to CD set/).to_stdout
      end

      it 'sets boot to CD with Legacy mode' do
        cli.options[:legacy] = true
        allow(mock_client).to receive(:set_boot_override)
          .with('Cd', persistence: 'Once', mode: 'Legacy')
          .and_return(true)
        expect { cli.boot('cd') }.to output(/Boot to CD set/).to_stdout
      end

      it 'sets boot to CD with continuous persistence' do
        cli.options[:continuous] = true
        allow(mock_client).to receive(:set_boot_override)
          .with('Cd', persistence: 'Continuous', mode: nil)
          .and_return(true)
        expect { cli.boot('cd') }.to output(/Boot to CD set/).to_stdout
      end
    end
  end

  describe 'environment variables' do
    it 'uses environment variables as fallback' do
      ENV['RADFISH_HOST'] = '10.0.0.1'
      ENV['RADFISH_USERNAME'] = 'envuser'
      ENV['RADFISH_PASSWORD'] = 'envpass'
      ENV['RADFISH_VENDOR'] = 'supermicro'
      ENV['RADFISH_PORT'] = '8443'
      
      cli.options = {}
      opts = cli.send(:load_options)
      
      expect(opts[:host]).to eq('10.0.0.1')
      expect(opts[:username]).to eq('envuser')
      expect(opts[:password]).to eq('envpass')
      expect(opts[:vendor]).to eq('supermicro')
      expect(opts[:port]).to eq(8443)
      
      # Clean up
      ENV.delete('RADFISH_HOST')
      ENV.delete('RADFISH_USERNAME')
      ENV.delete('RADFISH_PASSWORD')
      ENV.delete('RADFISH_VENDOR')
      ENV.delete('RADFISH_PORT')
    end
  end
end
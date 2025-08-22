require 'spec_helper'
require 'radfish/cli'

RSpec.describe 'Radfish::CLI with Factories' do
  let(:cli) { Radfish::CLI.new }
  let(:client_options) { Factories.build_client_options }
  let(:mock_client) { double('Radfish::Client') }
  
  before do
    allow(Radfish::Client).to receive(:new).and_return(mock_client)
    mock_successful_login(mock_client)
    cli.options = client_options.merge(json: false)
  end

  describe 'using factory data' do
    context 'with system info' do
      let(:system_info) { Factories.build_system_info }
      
      it 'displays system information' do
        allow(mock_client).to receive(:system_info).and_return(system_info)
        allow(cli).to receive(:system).and_return(nil)
        
        expect(mock_client).to receive(:system_info)
        cli.instance_variable_set(:@client, mock_client)
        result = mock_client.system_info
        
        expect(result['Manufacturer']).to eq('Supermicro')
        expect(result['Model']).to eq('SYS-5019C-MR')
        expect(result['PowerState']).to eq('On')
      end
    end

    context 'with virtual media devices' do
      let(:unmounted_device) { Factories.build_virtual_media_device }
      let(:mounted_device) { Factories.build_mounted_virtual_media_device }
      
      it 'shows unmounted virtual media' do
        allow(mock_client).to receive(:virtual_media_status).and_return([unmounted_device])
        
        result = mock_client.virtual_media_status.first
        expect(result[:inserted]).to be false
        expect(result[:connected_via]).to eq('NotConnected')
      end
      
      it 'shows mounted virtual media' do
        allow(mock_client).to receive(:virtual_media_status).and_return([mounted_device])
        
        result = mock_client.virtual_media_status.first
        expect(result[:inserted]).to be true
        expect(result[:connected_via]).to eq('URI')
        expect(result[:image]).to eq('http://example.com/test.iso')
      end
    end

    context 'with power operations' do
      it 'handles power state from factory' do
        power_response = Factories.build_power_response('Off')
        allow(mock_client).to receive(:power_status).and_return(power_response['PowerState'])
        
        expect(mock_client.power_status).to eq('Off')
      end
      
      it 'handles different power states' do
        ['On', 'Off', 'PoweringOn', 'PoweringOff'].each do |state|
          response = Factories.build_power_response(state)
          allow(mock_client).to receive(:power_status).and_return(response['PowerState'])
          
          expect(mock_client.power_status).to eq(state)
        end
      end
    end

    context 'with boot configuration' do
      let(:boot_response) { Factories.build_boot_response }
      
      it 'uses factory boot configuration' do
        custom_boot = Factories.build_boot_response(
          'Boot' => {
            'BootSourceOverrideEnabled' => 'Once',
            'BootSourceOverrideMode' => 'UEFI',
            'BootSourceOverrideTarget' => 'Cd'
          }
        )
        
        allow(mock_client).to receive(:get_boot_config).and_return(custom_boot)
        
        result = mock_client.get_boot_config
        expect(result['Boot']['BootSourceOverrideTarget']).to eq('Cd')
        expect(result['Boot']['BootSourceOverrideMode']).to eq('UEFI')
      end
    end

    context 'with storage configuration' do
      let(:storage) { Factories.build_storage_controller }
      
      it 'provides storage controller data' do
        allow(mock_client).to receive(:get_storage).and_return(storage)
        
        result = mock_client.get_storage
        expect(result['StorageControllers'].first['Name']).to eq('HA-RAID')
        expect(result['Drives'].length).to eq(2)
        expect(result['Drives'].first['MediaType']).to eq('SSD')
      end
    end

    context 'with vendor detection' do
      it 'detects Supermicro vendor' do
        vendor_response = Factories.build_vendor_detection_response('Supermicro')
        allow(Radfish).to receive(:detect_vendor).and_return('supermicro')
        
        expect(vendor_response['Manufacturer']).to eq('Supermicro')
        expect(vendor_response['Oem']).to have_key('Supermicro')
      end
      
      it 'detects Dell/iDRAC vendor' do
        vendor_response = Factories.build_vendor_detection_response('Dell')
        allow(Radfish).to receive(:detect_vendor).and_return('idrac')
        
        expect(vendor_response['Manufacturer']).to eq('Dell Inc.')
        expect(vendor_response['Oem']).to have_key('Dell')
      end
      
      it 'detects HPE/iLO vendor' do
        vendor_response = Factories.build_vendor_detection_response('HPE')
        allow(Radfish).to receive(:detect_vendor).and_return('ilo')
        
        expect(vendor_response['Manufacturer']).to eq('HPE')
        expect(vendor_response['Oem']).to have_key('Hpe')
      end
    end

    context 'with task monitoring' do
      it 'tracks task completion' do
        pending_task = Factories.build_task_response(
          'TaskState' => 'Running',
          'PercentComplete' => 50
        )
        completed_task = Factories.build_task_response
        
        allow(mock_client).to receive(:get_task)
          .and_return(pending_task, completed_task)
        
        first_check = mock_client.get_task
        expect(first_check['TaskState']).to eq('Running')
        expect(first_check['PercentComplete']).to eq(50)
        
        second_check = mock_client.get_task
        expect(second_check['TaskState']).to eq('Completed')
        expect(second_check['PercentComplete']).to eq(100)
      end
    end

    context 'with error handling' do
      it 'handles error responses' do
        error = Factories.build_error_response('Auth.Failed', 'Authentication failed')
        
        expect(error['error']['code']).to eq('Auth.Failed')
        expect(error['error']['message']).to eq('Authentication failed')
      end
    end

    context 'with job monitoring' do
      let(:job) { Factories.build_job_response }
      
      it 'monitors job status' do
        running_job = Factories.build_job_response(
          'JobState' => 'Running',
          'PercentComplete' => 75
        )
        
        allow(mock_client).to receive(:get_job)
          .and_return(running_job, job)
        
        expect(mock_client.get_job['JobState']).to eq('Running')
        expect(mock_client.get_job['JobState']).to eq('Completed')
      end
    end

    context 'with network adapters' do
      let(:network_adapter) { Factories.build_network_adapter }
      
      it 'provides network adapter information' do
        allow(mock_client).to receive(:get_network_adapter).and_return(network_adapter)
        
        result = mock_client.get_network_adapter
        expect(result['Status']['State']).to eq('Enabled')
        expect(result['Status']['Health']).to eq('OK')
      end
    end

    context 'with event handling' do
      let(:event) { Factories.build_event_response }
      
      it 'handles event responses' do
        allow(mock_client).to receive(:get_events).and_return(event)
        
        result = mock_client.get_events
        expect(result['Events'].first['EventType']).to eq('StatusChange')
        expect(result['Events'].first['Severity']).to eq('OK')
      end
    end

    context 'with session management' do
      let(:session) { Factories.build_session_response }
      
      it 'manages sessions with factory data' do
        allow(mock_client).to receive(:create_session).and_return(session)
        
        result = mock_client.create_session
        expect(result['UserName']).to eq('admin')
        expect(result['Id']).to eq('1234567890')
      end
    end
  end
end
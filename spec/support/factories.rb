module Factories
  class << self
    def build_client_options(overrides = {})
      {
        host: '192.168.1.100',
        username: 'admin',
        password: 'password',
        port: 443,
        vendor: 'auto',
        timeout: 30,
        verify_ssl: false
      }.merge(overrides)
    end

    def build_system_info(overrides = {})
      {
        'UUID' => 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
        'BiosVersion' => 'U32 v2.31 (12/16/2022)',
        'HostName' => 'test-server',
        'Manufacturer' => 'Supermicro',
        'Model' => 'SYS-5019C-MR',
        'SerialNumber' => 'S123456789',
        'PowerState' => 'On',
        'Status' => {
          'State' => 'Enabled',
          'Health' => 'OK'
        },
        'MemorySummary' => {
          'TotalSystemMemoryGiB' => 64,
          'Status' => {
            'State' => 'Enabled',
            'Health' => 'OK'
          }
        },
        'ProcessorSummary' => {
          'Count' => 1,
          'Model' => 'Intel(R) Xeon(R) E-2276G CPU @ 3.80GHz',
          'Status' => {
            'State' => 'Enabled',
            'Health' => 'OK'
          }
        }
      }.merge(overrides)
    end

    def build_virtual_media_device(overrides = {})
      {
        device: 'VirtualMedia1',
        name: 'Virtual Removable Media',
        inserted: false,
        image: nil,
        connected_via: 'NotConnected',
        media_types: ['CD', 'DVD', 'Floppy', 'USBStick']
      }.merge(overrides)
    end

    def build_mounted_virtual_media_device(iso_url = 'http://example.com/test.iso')
      build_virtual_media_device(
        inserted: true,
        image: iso_url,
        connected_via: 'URI'
      )
    end

    def build_power_response(state = 'On')
      {
        'PowerState' => state,
        '@odata.id' => '/redfish/v1/Systems/1',
        '@odata.type' => '#ComputerSystem.v1_13_0.ComputerSystem'
      }
    end

    def build_boot_response(overrides = {})
      {
        'Boot' => {
          'BootOptions' => {
            '@odata.id' => '/redfish/v1/Systems/1/BootOptions'
          },
          'BootOrder' => ['Boot0001', 'Boot0002', 'Boot0003'],
          'BootSourceOverrideEnabled' => 'Disabled',
          'BootSourceOverrideMode' => 'UEFI',
          'BootSourceOverrideTarget' => 'None',
          'UefiTargetBootSourceOverride' => nil
        }
      }.merge(overrides)
    end

    def build_task_response(overrides = {})
      {
        '@odata.id' => '/redfish/v1/TaskService/Tasks/1',
        '@odata.type' => '#Task.v1_4_3.Task',
        'Id' => '1',
        'Name' => 'Task 1',
        'TaskState' => 'Completed',
        'TaskStatus' => 'OK',
        'StartTime' => '2024-01-01T12:00:00-06:00',
        'EndTime' => '2024-01-01T12:00:30-06:00',
        'PercentComplete' => 100,
        'Messages' => []
      }.merge(overrides)
    end

    def build_storage_controller(overrides = {})
      {
        '@odata.id' => '/redfish/v1/Systems/1/Storage/HA-RAID',
        'Id' => 'HA-RAID',
        'Name' => 'HA-RAID',
        'StorageControllers' => [
          {
            '@odata.id' => '/redfish/v1/Systems/1/Storage/HA-RAID#/StorageControllers/0',
            'MemberId' => '0',
            'Name' => 'HA-RAID',
            'Status' => {
              'State' => 'Enabled',
              'Health' => 'OK'
            },
            'Manufacturer' => 'Supermicro',
            'Model' => 'Supermicro RAID Controller',
            'FirmwareVersion' => '4.680.00-8290'
          }
        ],
        'Drives' => [
          build_drive,
          build_drive(Id: 'Disk.Bay.1', Name: 'Disk.Bay.1', SerialNumber: 'S456DEF789')
        ]
      }.merge(overrides)
    end

    def build_drive(overrides = {})
      {
        '@odata.id' => '/redfish/v1/Systems/1/Storage/HA-RAID/Drives/Disk.Bay.0',
        'Id' => 'Disk.Bay.0',
        'Name' => 'Disk.Bay.0',
        'Model' => 'SAMSUNG MZ7L3960HBLT-00A07',
        'Manufacturer' => 'SAMSUNG',
        'SerialNumber' => 'S123ABC456',
        'CapacityBytes' => 960197124096,
        'Protocol' => 'SATA',
        'MediaType' => 'SSD',
        'Status' => {
          'State' => 'Enabled',
          'Health' => 'OK'
        }
      }.merge(overrides)
    end

    def build_session_response(overrides = {})
      {
        '@odata.id' => '/redfish/v1/SessionService/Sessions/1234567890',
        '@odata.type' => '#Session.v1_3_0.Session',
        'Id' => '1234567890',
        'Name' => 'User Session',
        'UserName' => 'admin',
        'Oem' => {}
      }.merge(overrides)
    end

    def build_error_response(code = 'Base.1.0.GeneralError', message = 'An error occurred')
      {
        'error' => {
          'code' => code,
          'message' => message,
          '@Message.ExtendedInfo' => [
            {
              '@odata.type' => '#Message.v1_0_0.Message',
              'MessageId' => code,
              'Message' => message,
              'Severity' => 'Critical'
            }
          ]
        }
      }
    end

    def build_job_response(overrides = {})
      {
        '@odata.id' => '/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/JID_123456789',
        '@odata.type' => '#DellJob.v1_0_0.DellJob',
        'Id' => 'JID_123456789',
        'Name' => 'Configure: RAID.Integrated.1-1',
        'JobState' => 'Completed',
        'JobType' => 'RAIDConfiguration',
        'PercentComplete' => 100,
        'Message' => 'Job completed successfully.',
        'MessageId' => 'SYS055',
        'StartTime' => 'TIME_NOW',
        'EndTime' => 'TIME_NA'
      }.merge(overrides)
    end

    def build_vendor_detection_response(vendor = 'Supermicro')
      case vendor.downcase
      when 'supermicro'
        {
          'Oem' => {
            'Supermicro' => {
              '@odata.type' => '#SmcComputerSystem.v1_0_0.Supermicro'
            }
          },
          'Manufacturer' => 'Supermicro'
        }
      when 'dell', 'idrac'
        {
          'Oem' => {
            'Dell' => {
              '@odata.type' => '#DellComputerSystem.v1_0_0.DellComputerSystem'
            }
          },
          'Manufacturer' => 'Dell Inc.'
        }
      when 'hpe', 'ilo'
        {
          'Oem' => {
            'Hpe' => {
              '@odata.type' => '#HpeComputerSystem.v1_0_0.HpeComputerSystem'
            }
          },
          'Manufacturer' => 'HPE'
        }
      else
        {
          'Manufacturer' => vendor
        }
      end
    end

    def build_redfish_service_root
      {
        '@odata.id' => '/redfish/v1',
        '@odata.type' => '#ServiceRoot.v1_5_0.ServiceRoot',
        'Id' => 'ServiceRoot',
        'Name' => 'Root Service',
        'RedfishVersion' => '1.9.0',
        'UUID' => '92384634-2938-2342-8820-489239905423',
        'Systems' => {
          '@odata.id' => '/redfish/v1/Systems'
        },
        'Chassis' => {
          '@odata.id' => '/redfish/v1/Chassis'
        },
        'Managers' => {
          '@odata.id' => '/redfish/v1/Managers'
        },
        'SessionService' => {
          '@odata.id' => '/redfish/v1/SessionService'
        },
        'UpdateService' => {
          '@odata.id' => '/redfish/v1/UpdateService'
        }
      }
    end

    def build_network_adapter(overrides = {})
      {
        '@odata.id' => '/redfish/v1/Systems/1/NetworkInterfaces/1',
        'Id' => '1',
        'Name' => 'Network Interface',
        'Status' => {
          'State' => 'Enabled',
          'Health' => 'OK'
        },
        'NetworkPorts' => {
          '@odata.id' => '/redfish/v1/Systems/1/NetworkInterfaces/1/NetworkPorts'
        }
      }.merge(overrides)
    end

    def build_event_response(overrides = {})
      {
        '@odata.id' => '/redfish/v1/EventService/Events/1',
        'Id' => '1',
        'Name' => 'Event 1',
        'Events' => [
          {
            'EventType' => 'StatusChange',
            'EventId' => '12345',
            'Severity' => 'OK',
            'Message' => 'The resource has been created successfully.',
            'MessageId' => 'ResourceEvent.1.0.ResourceCreated',
            'EventTimestamp' => '2024-01-01T12:00:00-06:00'
          }
        ]
      }.merge(overrides)
    end
  end
end
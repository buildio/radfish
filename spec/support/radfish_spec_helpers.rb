module RadfishSpecHelpers
  def mock_successful_login(client)
    allow(client).to receive(:login).and_return(true)
    allow(client).to receive(:logout).and_return(true)
  end

  def mock_power_status(client, status = 'On')
    allow(client).to receive(:power_status).and_return(status)
  end

  def mock_virtual_media(client, devices = [])
    default_devices = devices.empty? ? default_virtual_media_devices : devices
    allow(client).to receive(:virtual_media_status).and_return(default_devices)
  end

  def default_virtual_media_devices
    [
      {
        device: 'VirtualMedia1',
        name: 'Virtual Removable Media',
        inserted: false,
        image: nil,
        connected_via: 'NotConnected',
        media_types: ['CD', 'DVD', 'Floppy', 'USBStick']
      },
      {
        device: 'VirtualMedia2',
        name: 'Virtual Removable Media',
        inserted: false,
        image: nil,
        connected_via: 'NotConnected',
        media_types: ['CD', 'DVD', 'Floppy', 'USBStick']
      }
    ]
  end

  def capture_stdout(&block)
    original_stdout = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  def capture_stderr(&block)
    original_stderr = $stderr
    $stderr = StringIO.new
    block.call
    $stderr.string
  ensure
    $stderr = original_stderr
  end

  def with_env_vars(vars)
    old_values = {}
    vars.each do |key, value|
      old_values[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    old_values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
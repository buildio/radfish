# Radfish - Unified Redfish Client

A Ruby client library that provides a unified interface for managing servers via Redfish API, with automatic vendor detection and adaptation.

## Data Normalization

Radfish takes a minimal approach to data normalization to ensure consistency across different systems and avoid mismatches from varying formats:

- **Manufacturer/Make**: Returns simplified vendor names (e.g., "Dell" instead of "Dell Inc.", "Supermicro" instead of "Super Micro Computer")
- **Model**: Returns core model identifiers without marketing prefixes (e.g., "R640" instead of "PowerEdge R640")
- **Consistent Fields**: All adapters normalize their data to use the same field names and formats

This approach minimizes potential mismatches across older systems or spacing/hyphenation issues with multi-token descriptors.

## Architecture

Radfish provides a vendor-agnostic interface for server management through Redfish, automatically detecting and adapting to different hardware vendors. The architecture consists of:

```
radfish (core gem)
├── Core modules (define interfaces)
├── Vendor detection
├── Client (delegates to adapters)
└── Base classes

radfish-idrac (Dell adapter)
└── IdracAdapter → wraps idrac gem

radfish-supermicro (Supermicro adapter)  
└── SupermicroAdapter → wraps supermicro gem

Future adapters:
- radfish-hpe (HPE iLO)
- radfish-lenovo (Lenovo XCC)
- radfish-asrockrack
```

### The HTTP layer

`Radfish::HttpClient` is the single seam between the library and the network.
Faraday is an implementation detail behind it: the vendor detector, the core
classes and the adapters talk to `HttpClient` (or to `BaseClient#http_get` and
friends, which delegate to it) and never build a Faraday connection of their
own. Everything that BMCs make awkward lives in that one class - permissive TLS
for old firmware, the `Host` header for SSH tunnels, retries, redirects, debug
logging, and the translation of transport failures into Radfish errors.

Two consequences worth knowing:

- **Callers rescue Radfish errors, not Faraday errors.** `HttpClient` converts
  Faraday's connection, timeout and SSL failures into `Radfish::ConnectionError`
  and `Radfish::TimeoutError`. Code above the seam that rescues `Faraday::Error`
  catches nothing.
- **Adapters that wrap another gem are outside the seam.** The Dell and
  Supermicro adapters delegate to the `idrac` and `supermicro` gems, which have
  their own HTTP stacks, so the behaviour described here does not apply to their
  requests.

#### Errors

All library errors descend from `Radfish::Error`, so one rescue catches
everything the library raises:

```
Radfish::Error
├── Radfish::ConnectionError        # unreachable host, refused connection, TLS failure
├── Radfish::TimeoutError           # request took too long
│   └── Radfish::BootProgressTimeout
├── Radfish::AuthenticationError    # bad credentials
├── Radfish::NotFoundError
├── Radfish::UnsupportedVendorError # no adapter for this BMC
├── Radfish::VirtualMediaError      # + NotFound / Connection / License / Busy
└── Radfish::TaskError              # + TaskTimeoutError / TaskFailedError
```

#### Retries

Failed requests are retried with an exponential backoff on 408, 429, 500, 502,
503 and 504, and on connection and timeout failures. **Only idempotent methods
are retried** - GET, HEAD, PUT and DELETE. A repeated POST is not safe on
Redfish: it can mean a second session, a second reset, or a second job. A caller
that knows its POST is safe to repeat can widen the set for one client:

```ruby
Radfish::HttpClient.new(
  host: '192.168.1.100',
  retry_count: 3,                    # attempts after the first
  retry_delay: 1,                    # initial delay, doubled each retry
  retry_methods: Radfish::HttpClient::IDEMPOTENT_METHODS + [:post]
)
```

For a whole operation rather than a single request, `BaseClient#with_retries`
wraps a block.

#### Redirects

Some BMCs (AMI MegaRAC, for one) redirect `/redfish/v1` to `/redfish/v1/`.
`HttpClient` follows redirects on GET and HEAD, up to `max_redirects` hops
(3 by default; pass `max_redirects: 0` on a call to get the 3xx response
itself). A redirect is only followed back to the same endpoint - a relative
path, or an absolute URL whose scheme, host and port match the BMC already
being addressed - because every request carries credentials and Faraday would
otherwise hand them to whatever host the `Location` header named. POST and
PATCH redirects are returned to the caller rather than followed, since
301/302/303 do not preserve the method.

## Features

### Automatic Vendor Detection
- Automatically identifies Dell, Supermicro, HPE, Lenovo, and ASRockRack servers
- Falls back to generic Redfish if vendor cannot be determined
- Can be overridden with explicit vendor specification

### Unified Interface
Regardless of vendor, all adapters provide:

- **Power Management**: on/off/restart/cycle
- **System Inventory**: CPUs, memory, NICs, storage
- **Virtual Media**: Mount/unmount ISOs
- **Boot Configuration**: Boot order, one-time boot
- **Monitoring**: Temperatures, fans, power consumption
- **Event Logs**: System event log management
- **Jobs/Tasks**: Long-running operation monitoring

### Vendor-Specific Features
Adapters can expose vendor-specific functionality while maintaining the common interface.

## Compatibility

`activesupport` below 8.1 and `json` 3 cannot be used together: activesupport's
JSON encoder calls `JSON.generate(..., quirks_mode: true)`, and json 3 removed
that keyword, so any `hash.to_json` raises `ArgumentError: unknown keyword:
quirks_mode`. This is not specific to this gem — it bites anything that loads
`active_support/core_ext` — but radfish depends on activesupport, so pick one
of:

- activesupport >= 8.1 with json 3, or
- activesupport 7.x with json 2.

CI covers both ends.

## Installation

Add to your Gemfile:

```ruby
gem 'radfish'

# Add vendor-specific adapters as needed
gem 'radfish-idrac'      # For Dell servers
gem 'radfish-supermicro'  # For Supermicro servers
```

Or install directly:

```bash
gem install radfish
gem install radfish-idrac      # For Dell servers  
gem install radfish-supermicro  # For Supermicro servers
```

The adapters will be automatically detected and loaded when available.

## CLI Usage

Radfish includes a powerful command-line interface for server management:

### Quick Start

```bash
# Check system status
radfish system --host 192.168.1.100 -u admin -p password

# Power operations
radfish power status --host 192.168.1.100 -u admin -p password
radfish power on --host 192.168.1.100 -u admin -p password
radfish power restart --host 192.168.1.100 -u admin -p password

# Virtual media operations
radfish media status --host 192.168.1.100 -u admin -p password
radfish media mount https://example.com/ubuntu.iso --host 192.168.1.100 -u admin -p password
radfish media unmount --host 192.168.1.100 -u admin -p password

# Boot configuration
radfish boot status --host 192.168.1.100 -u admin -p password
radfish boot cd --once --host 192.168.1.100 -u admin -p password
radfish boot pxe --uefi --host 192.168.1.100 -u admin -p password
```

### Environment Variables

Configure common settings via environment variables to avoid repetition:

```bash
export RADFISH_HOST=192.168.1.100
export RADFISH_USERNAME=admin
export RADFISH_PASSWORD=password
export RADFISH_VENDOR=supermicro  # Optional: auto-detects if not set
export RADFISH_PORT=443           # Optional: defaults to 443

# Now commands are simpler
radfish system
radfish power on
radfish media mount https://example.com/ubuntu.iso
```

### Available Commands

#### System Information
```bash
radfish system [OPTIONS]           # Display system information
radfish cpus [OPTIONS]             # List CPUs
radfish memory [OPTIONS]           # List memory modules
radfish nics [OPTIONS]             # List network interfaces
radfish storage controllers        # List storage controllers
radfish storage drives             # List drives across controllers
radfish storage volumes            # List volumes across controllers
radfish psus [OPTIONS]             # List power supplies
```

#### Power Management
```bash
radfish power status [OPTIONS]     # Show current power state
radfish power on [OPTIONS]         # Power on the system
radfish power off [OPTIONS]        # Power off the system
radfish power restart [OPTIONS]    # Restart the system
radfish power cycle [OPTIONS]      # Power cycle the system
```

#### Virtual Media
```bash
radfish media status [OPTIONS]     # Show virtual media status
radfish media mount URL [OPTIONS]  # Mount ISO from URL
radfish media unmount [OPTIONS]    # Unmount all virtual media
```

#### Boot Configuration
```bash
radfish boot status [OPTIONS]      # Show boot configuration
radfish boot cd [OPTIONS]          # Boot from virtual CD
radfish boot pxe [OPTIONS]         # Boot from network (PXE)
radfish boot disk [OPTIONS]        # Boot from hard disk
radfish boot bios [OPTIONS]        # Boot to BIOS setup

# Boot options:
  --once        # Set boot override for next boot only
  --continuous  # Set boot override until manually cleared
  --uefi        # Use UEFI boot mode
  --legacy      # Use Legacy/BIOS boot mode
```

#### Monitoring
```bash
radfish fans [OPTIONS]              # Show fan speeds
radfish temps [OPTIONS]             # Show temperatures
radfish power-consumption [OPTIONS] # Show power consumption
radfish sel [OPTIONS]               # Show system event log
radfish clear-sel [OPTIONS]         # Clear system event log
```

### Global Options

All commands support these options:

```bash
  --host, -h HOST          # BMC hostname or IP address
  --username, -u USER      # BMC username
  --password, -p PASS      # BMC password
  --vendor, -v VENDOR      # Force specific vendor (dell, supermicro, etc.)
  --port PORT              # BMC port (default: 443)
  --config, -c FILE        # Read options from a YAML config file
  --json                   # Output in JSON format
  --verbose                # Application-level progress messages
  --debug [N]              # HTTP-level debug output (default 2, see below)
  --insecure               # Skip SSL certificate verification (default: true)
```

`--verbose` and `--debug` set the same verbosity level, and `--debug` wins:

| Level | Flag          | Output                                              |
|-------|---------------|-----------------------------------------------------|
| 0     | (none)        | Results only                                        |
| 1     | `--verbose`   | Progress messages from the library                  |
| 2     | `--debug`     | Adds the HTTP request and response log              |
| 3     | `--debug 3`   | Adds request and response bodies, and call sites    |

The `Authorization` header and password fields are filtered out of the log, but
level 3 prints request and response bodies, which can carry other sensitive
data - read it before pasting it into an issue.

### Output Formats

#### Default (Human-Readable)
```bash
$ radfish system
System Information:
  Manufacturer: Supermicro
  Model: X11SCL-F
  Serial: 0123456789
  Power State: On
  Health: OK
```

#### JSON Format
```bash
$ radfish system --json
{
  "manufacturer": "Supermicro",
  "model": "X11SCL-F",
  "serial": "0123456789",
  "power_state": "On",
  "health": "OK"
}
```

### Common Workflows

#### Mount ISO and Boot from It
```bash
# Mount the ISO
radfish media mount https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

# Configure one-time boot from CD with UEFI
radfish boot cd --once --uefi

# Restart the system
radfish power restart
```

#### Power Cycle with Monitoring
```bash
# Check current status
radfish power status
radfish temps

# Perform power cycle
radfish power cycle

# Monitor until back online
watch radfish power status
```

#### Automated Script Example
```bash
#!/bin/bash
# Provision multiple servers

SERVERS="192.168.1.100 192.168.1.101 192.168.1.102"
ISO_URL="https://example.com/os-installer.iso"

for server in $SERVERS; do
  echo "Provisioning $server..."
  
  # Mount ISO
  radfish media mount $ISO_URL --host $server -u admin -p password
  
  # Set one-time boot from CD
  radfish boot cd --once --host $server -u admin -p password
  
  # Restart
  radfish power restart --host $server -u admin -p password
done
```

## Library Usage

### Basic Usage with Auto-Detection

```ruby
require 'radfish'

# Auto-detect vendor and connect
Radfish.connect(
  host: '192.168.1.100',
  username: 'admin',
  password: 'password'
) do |client|
  puts "Connected to #{client.vendor_name} server"
  puts "Power state: #{client.power_status}"
  
  # Common operations work regardless of vendor
  client.power_on
  client.insert_virtual_media("http://example.com/os.iso")
  client.boot_to_cd
end
```

### Explicit Vendor Specification

```ruby
# Skip auto-detection if you know the vendor
client = Radfish::Client.new(
  host: '192.168.1.100',
  username: 'admin',
  password: 'password',
  vendor: 'dell'  # or 'supermicro', 'hpe', etc.
)

client.login
# ... operations ...
client.logout
```

### Vendor Detection Only

```ruby
# Just detect the vendor without creating a client
vendor = Radfish.detect_vendor(
  host: '192.168.1.100',
  username: 'admin',
  password: 'password'
)
puts "Detected vendor: #{vendor}"
# => "dell", "supermicro", "hpe", etc.
```

### Checking Supported Features

```ruby
client = Radfish::Client.new(
  host: '192.168.1.100',
  username: 'admin',
  password: 'password'
)

# Check what this adapter supports
puts client.supported_features
# => [:power, :system, :storage, :virtual_media, :boot, :jobs, :utility]

# Get adapter info
puts client.info
# => {
#   vendor: "supermicro",
#   adapter: "Radfish::SupermicroAdapter",
#   features: [:power, :system, ...],
#   host: "192.168.1.100",
#   base_url: "https://192.168.1.100:443"
# }
```

## Common Operations

### Power Management

```ruby
client.power_status      # => "On" or "Off"
client.power_on
client.power_off
client.power_restart
client.power_cycle
```

### System Information

```ruby
# Basic system info
info = client.system_info
# => { "manufacturer" => "Dell", "model" => "PowerEdge R640", ... }

# Hardware inventory
client.cpus      # CPU information
client.memory    # Memory DIMMs
client.nics      # Network interfaces
client.controllers.each { |c| c.drives }   # Physical drives (per controller)
client.controllers.each { |c| c.volumes }  # RAID volumes (per controller)
client.psus      # Power supplies
```

### Virtual Media

```ruby
# Check current media
media = client.virtual_media_status

# Mount an ISO
client.insert_virtual_media("http://example.com/os.iso")

# Unmount all media
client.unmount_all_media

# Mount and configure boot
client.mount_iso_and_boot("http://example.com/os.iso")
```

### Boot Configuration

```ruby
# Get boot options
options = client.boot_options

# Set one-time boot
client.set_boot_override("Pxe", persistence: 'Once')

# Quick boot methods
client.boot_to_pxe
client.boot_to_disk
client.boot_to_cd
client.boot_to_bios_setup
```

### Monitoring

```ruby
# Thermal monitoring
fans = client.fans
temps = client.temperatures

# Power monitoring
power = client.power_consumption

# Event logs
events = client.sel_summary(limit: 10)
client.clear_sel_log
```

## Multi-Vendor Environments

Radfish shines in environments with mixed hardware vendors:

```ruby
servers = [
  { host: '192.168.1.100', vendor: 'dell' },
  { host: '192.168.1.101', vendor: 'supermicro' },
  { host: '192.168.1.102', vendor: nil }  # auto-detect
]

servers.each do |server_config|
  Radfish.connect(
    host: server_config[:host],
    username: 'admin',
    password: 'password',
    vendor: server_config[:vendor]
  ) do |client|
    # Same code works for all vendors
    puts "#{client.vendor_name}: #{client.power_status}"
    
    if client.power_status == "Off"
      client.power_on
    end
  end
end
```

## Configuration Options

```ruby
Radfish::Client.new(
  host: '192.168.1.100',
  username: 'admin',
  password: 'password',
  
  # Optional parameters
  vendor: 'dell',           # Skip auto-detection
  port: 443,                # BMC port
  use_ssl: true,            # Use HTTPS
  verify_ssl: false,        # Verify certificates
  direct_mode: false,       # Use Basic Auth instead of sessions
  retry_count: 3,           # Retries after the first attempt
  retry_delay: 1,           # Initial delay between retries, doubled each time
  retry_methods: nil,       # Defaults to idempotent methods only
  max_redirects: 3,         # Same-endpoint redirects to follow (0 disables)
  verbosity: 0              # Debug output level (0-3)
)
```

## Debugging

Enable verbose output:

```ruby
client.verbosity = 1  # Progress messages from the library
client.verbosity = 2  # Adds the HTTP request and response log
client.verbosity = 3  # Adds request and response bodies, and call sites
```

These are the same levels the CLI sets with `--verbose` and `--debug N`. The
`Authorization` header and password fields are filtered out of the log.

## Supported Vendors

Currently supported:
- **Dell** (via radfish-idrac)
- **Supermicro** (via radfish-supermicro)

Planned support:
- **HPE** (iLO)
- **Lenovo** (XCC)
- **ASRockRack**
- **Generic Redfish** (fallback)

## Creating Custom Adapters

To add support for a new vendor, create an adapter gem:

```ruby
# radfish-myvendor/lib/radfish/myvendor_adapter.rb
module Radfish
  class MyvendorAdapter < Core::BaseClient
    include Core::Power
    include Core::System
    # ... include other modules
    
    def vendor
      'myvendor'
    end
    
    def power_status
      # Implement vendor-specific logic
    end
    
    # ... implement required methods
  end
  
  # Register the adapter
  Radfish.register_adapter('myvendor', MyvendorAdapter)
end
```

## Benefits of the Unified Approach

1. **Single API**: Learn once, use everywhere
2. **Vendor Flexibility**: Switch hardware vendors without changing code
3. **Automatic Detection**: No need to track which vendor each server uses
4. **Gradual Migration**: Mix vendors during hardware transitions
5. **Simplified Testing**: Mock one interface instead of many
6. **Future-Proof**: New vendors can be added without changing existing code

## Migration from Direct Vendor Gems

If you're currently using the idrac or supermicro gems directly:

```ruby
# Old way (vendor-specific)
require 'idrac'
client = IDRAC::Client.new(host: '...', ...)

# New way (unified)
require 'radfish'
require 'radfish/idrac_adapter'  # or let it auto-load
client = Radfish::Client.new(host: '...', vendor: 'dell')

# Or with auto-detection
client = Radfish::Client.new(host: '...') 
```

The same method names work, so migration is straightforward.

## License

MIT

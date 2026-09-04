# frozen_string_literal: true

module Radfish
  # Boot configuration facade. Reached as +client.boot+.
  #
  # The vendor-neutral entry point for the boot mechanics that used to be hand-rolled in raw
  # Redfish by callers (reading BootSources, disabling stale UEFI placeholders, scheduling the
  # config job). The heavy lifting lives in the adapter; this object just exposes it cleanly and
  # keeps +to_h+ pointing at the underlying boot configuration for backward compatibility.
  class BootInfo
    attr_reader :client

    def initialize(client)
      @client = client
    end

    # The still-enabled stale UEFI boot placeholders (Dell: "Unknown.Unknown.*"). [] when the
    # adapter has nothing to report. Pass +match:+ to target a different set of entries.
    def stale_uefi_entries(match: nil)
      require_adapter!(:stale_uefi_boot_entries)
      match ? adapter.stale_uefi_boot_entries(match: match) : adapter.stale_uefi_boot_entries
    end

    # Disable the matched UEFI boot entries via a config job and return the names disabled.
    # With no +match:+ the adapter's default (the stale placeholders) applies. The adapter drains
    # any pending LC config job first, so this never trips LC068.
    def disable_entries(match: nil, **opts)
      require_adapter!(:disable_boot_entries)
      match ? adapter.disable_boot_entries(match: match, **opts) : adapter.disable_boot_entries(**opts)
    end

    # Underlying boot configuration hash (BootSourceOverride*, boot order, ...).
    def to_h
      adapter.boot_config
    end
    alias config to_h

    private

    def adapter
      @client.adapter
    end

    def require_adapter!(method)
      return if adapter.respond_to?(method)

      raise NotImplementedError, "#{@client.vendor_name} adapter does not support ##{method}"
    end
  end
end

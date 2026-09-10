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

    # One-time boot to the virtual CD via the vendor's reliable path (Dell: an SCP import that drains
    # any pending config job first, then sets ServerBoot BootOnce + FirstBootDevice=VCD-DVD). Returns
    # the vendor result; raises NotImplementedError on an adapter with no SCP one-time-boot path.
    def set_one_time_cd_boot(**opts)
      require_adapter!(:set_one_time_cd_boot)
      adapter.set_one_time_cd_boot(**opts)
    end

    # Poll the config job +jid+ (e.g. the BIOS config job a boot-source change schedules) to a
    # terminal state. Returns the state string, or nil on timeout (never raises).
    def wait_config_job(jid, **opts)
      require_adapter!(:wait_config_job)
      adapter.wait_config_job(jid, **opts)
    end

    # Drain every pending (non-Completed) config job so scheduling a new one does not trip LC068.
    # Returns the ids drained.
    def drain_config_jobs
      require_adapter!(:drain_pending_config_jobs!)
      adapter.drain_pending_config_jobs!
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

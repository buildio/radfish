# Changelog

## [0.3.0] - 2026-09-10
### Fixed
- `radfish boot <target>` raised `ArgumentError: unknown keyword: :persistence`
  on every vendor: the CLI passed `persistence:` while the adapters still took
  `enabled:` or `persistent:`. Fixed together with idrac 0.11.0,
  supermicro 0.2.0 and the adapter releases. (#7)
- `radfish storage --json` printed the human summary instead of JSON. (#3)
- `radfish detect --verbose` printed nothing: vendor detection runs in
  `Client.new`, so verbosity set afterwards arrived too late. (#3)
- Service-root redirects are followed, so BMCs that redirect `/redfish/v1` to
  `/redfish/v1/` (AMI MegaRAC) are detected. (#4)

### Changed
- **Breaking:** `Core::Boot#set_boot_override` takes `persistence:` and `mode:`
  instead of `persistent:`. (#7)
- Verbosity levels moved: `--verbose` is application messages, `--debug` (2)
  adds the HTTP request log, `--debug 3` adds bodies. (#3)
- Retries are limited to idempotent methods. A repeated POST could mean a
  second session, reset or job. Widen per client with `retry_methods:`. (#13)
- Redirects are followed only back to the same endpoint, by path, on GET and
  HEAD, up to `max_redirects` hops. Credentials never follow a `Location`
  header off-host. (#4)
- Debug log filters are case-insensitive and cover `X-Auth-Token`; `Session`
  no longer prints part of the token.

### Added
- `--debug N` on every CLI command. (#3)
- README documentation of the HTTP layer: `HttpClient` as the single seam with
  Faraday behind it, the `Radfish::Error` hierarchy, retry policy and the
  redirect rule. (#13)
- CI on push and pull request, and a release workflow publishing to RubyGems
  through trusted publishing (OIDC).

## [0.1.2] - 2025-08-28
### Fixed
- Updated ActiveSupport dependency to support Rails 8.x

## [0.1.0] - Initial Release
- Initial release of Radfish gem

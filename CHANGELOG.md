# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0.0] - Unreleased

### Changed

- The setting `metrics_url` is now `base_url`, labeled "Uptime Kuma address". It holds the address of Uptime Kuma, for example `https://uptime.example.com`; the plugin adds `/metrics` itself. The migration moves the saved value and strips a trailing `/metrics`, and the reverse migration adds it back. Run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production` when upgrading.
- New labels and hints, worded like the other Rubylode plugins: "Token variable" (was "Name of the token environment variable"), "Allow plain http" (was "Allow plain http (internal network)"), "Show in the top menu" (was "Add a Service status link to the top menu"). The Timeout seconds setting has a hint now.
- The placement settings are under "Show the block on" as Welcome page (was "The welcome page (Home)"), My page, Project Overview page (was "The project Overview page") and Pages matching these paths (was "Pages whose path is listed here"). Each column choice has a visible "Column" label. The setting keys are unchanged.
- The page of its own moved from `/service_status` to `/status/uptime_kuma`. The old address redirects there with a 301 for one release. Update bookmarks and links.
- The macro is `{{uptime_kuma_status}}`, the partial is `rubylode_uptime_kuma/status` and the My page block is `rubylode_uptime_kuma_status` (was "Service status"). The old macro `{{service_status}}`, the old partial `rubylode_uptime_kuma/service_status` and the old block id `rubylode_service_status` keep answering for one release. The old block id is no longer offered in the My page block list.
- The top menu caption is the block title (Services by default) instead of "Service status".
- Plugin code is in `RubylodeUptimeKuma`, and settings are read through `RubylodeUptimeKuma::Settings` (was `RedmineRubylodeUptimeKuma::Defaults` and `RubylodeUptimeKuma::Configuration`). Locale keys moved to `rubylode_uptime_kuma.settings.<key>.label` and `.hint`. A theme or plugin that calls these names or keys needs the new ones.
- The token variable error no longer says the plugin "can never read another secret". It says what the name must look like.
- The description no longer says "live": the answer is cached, 60 seconds by default.
- The response time placeholder is a hyphen instead of an en dash.
- The documentation uses en-US spelling.

### Added

- The block shows on the Status page of Rubylode Status when that plugin is installed: ok when every known service is up, a warning when some are down, down when all are, and unknown when Uptime Kuma cannot be reached or the plugin is not set up.
- Without Rubylode Status nothing changes. With it, the plugin's own top menu item and its "Show in the top menu" setting go away, and the settings page and the plugin page say so.

### Upgrading

1. Run the plugin migration (above).
2. Change bookmarks and links from `/service_status` to `/status/uptime_kuma`.
3. Change `{{service_status}}` in wiki pages to `{{uptime_kuma_status}}` when convenient; the old name stops working in the release after this one.
4. Check the top menu caption: it now follows the block title.


## [1.1.1] - 2026-11-04

### Changed

- Needs Redmine 5.1 or newer instead of 5.0. Redmine 5.0 cannot be tested in CI (the sqlite3 gem it pins does not build
  there), and this plugin only claims what CI verifies. No code changed.

## [1.1.0] - 2026-11-04

### Changed

- Runs on Redmine 5.0 and newer. The plugin's own tests pass unchanged on those versions; no code changed.

## [1.0.1] - 2026-11-03

### Added

- The plugin has a Rubylode thumbnail, shown at the top of the README.

### Changed

- The README is plainer and has a license section.
- The release job writes the checksum file inside the build step.

## [1.0.0] - 2026-11-02

First stable release.

### Added

- The plugins page in Administration shows the project address.
- The plugin's name, author and version match the redmine.org listing, so "Check for updates" can find it.

## [0.2.1] - 2026-11-02

### Fixed

- A cache that cannot be read or written (a cache file owned by another user, say) no longer breaks the page. The plugin logs a warning and builds the block by asking Kuma directly, or shows "Status unavailable".

## [0.2.0] - 2026-11-01

### Added

- "Show the block on" in the settings: the welcome page and the project Overview (each in the left or right column), My page (also in the default layout), pages whose path is on a list, and a top menu link to the status page.
- Path lists take `*` and `**` wildcards and are validated on save. The block shows in a compact form under the page content.
- A help table with copy-paste snippets for each place, on the settings page and in the README.
- The partial takes a `compact` local.

### Fixed

- The macro is styled in the wiki preview and other AJAX renders, which have no page head.

## [0.1.0] - 2026-11-01

First version. Needs Redmine 7.0 or newer.

### Added

- A status block read from Uptime Kuma's metrics. It lists the services you name, down ones first, shows unknown when no monitor matches, adds a summary line and response times, and falls back to "Status unavailable". Kuma is asked once per cache window.
- A wiki macro (`{{service_status}}`, also `{{uptime_kuma_status}}`), a page at `/service_status`, a My page block and a partial for other plugins.
- A settings page that validates on save: metrics URL, token variable name, allowed hosts, plain http switch, services list, dashboard link, cache and timeout seconds, block title, response time column and who may see the block.
- The token stays in the environment. Only `UPTIME_KUMA_*` names are read, the token goes only to an allowed host, over https unless the host is local or plain http is allowed, and redirects are not followed.
- Theming through `--rubylode-uptime-kuma-*` custom properties, with dark mode.
- A demo with a fake Kuma (`ruby bin/demo up`) and README screenshots.

[2.0.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v1.1.1...main
[1.1.1]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v0.2.1...v1.0.0
[0.2.1]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/releases/tag/v0.1.0

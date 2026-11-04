# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.0] - 2026-11-04

### Changed

- Runs on Redmine 5.0 and newer. The plugin's own tests pass unchanged on those versions; no code changed.

## [1.0.1] - 2026-11-03

### Added

- The plugin has a Rubylode thumbnail, shown at the top of the README.

### Changed

- The README is plainer and has a licence section.
- The changelog entries are worded more plainly.
- The release job writes the checksum file inside the build step.

## [1.0.0] - 2026-11-02

First stable release. A live service status block read from Uptime Kuma, as a wiki macro, a page, a My page block and a partial, with the places chosen in the settings.

### Added

- The plugins page in Administration shows the project address.
- The plugin's name, author and version match the redmine.org listing, so "Check for updates" can find it.

## [0.2.1] - 2026-11-02

### Fixed

- A cache that cannot be read or written (a cache file owned by another user, say) no longer breaks the page. The plugin logs a warning and builds the block from a live fetch, or shows "Status unavailable".

## [0.2.0] - 2026-11-01

### Added

- "Show the block on" in the settings: the welcome page and the project Overview (each in the left or right column), My page (also in the default layout), pages whose path is on a list, and a top menu link to the status page.
- Path lists take `*` and `**` wildcards and are validated on save. The block shows in a compact form under the page content.
- A table with snippets for the other places the block can go, on the settings page and in the README: the macro (also in the welcome text, news and descriptions), the My page block, the path list, the partial and its locals, and the standalone page.
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

[Unreleased]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v1.0.0...main
[1.0.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v0.2.1...v1.0.0
[0.2.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/releases/tag/v0.1.0

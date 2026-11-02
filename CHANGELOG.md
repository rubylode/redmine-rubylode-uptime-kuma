# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-11-01

### Added

- Choose where the block shows ("Show the block on" in the settings): the welcome page and the project Overview (each in the left or right column), My page (also in the default layout), pages whose path is on a list (a compact form under the content, with `*` and `**` wildcards, validated on save), and a top menu link to the status page.
- A "How to show the block on other pages" table with snippets on the settings page and in the README: the macro (also in the welcome text, news and descriptions), the My page block, the path list, the partial and its locals, and the standalone page.
- The partial takes a `compact` local.

### Fixed

- The macro is styled in the wiki preview and other AJAX renders, which have no page head.

## [0.1.0] - 2026-11-01

First version. Redmine 7.0 and newer.

### Added

- A status block read from Uptime Kuma's metrics: curated services, down first, unknown when no monitor matches, a summary line, response times, a "Status unavailable" fallback, and Kuma asked once per cache window.
- A wiki macro (`{{service_status}}`, also `{{uptime_kuma_status}}`), a page at `/service_status`, a My page block and a partial for other plugins.
- A settings page with validation on save: metrics URL, token variable name, allowed hosts, plain http switch, the services list, dashboard link, cache and timeout seconds, block title, response time column and who may see it.
- The token stays in the environment: only `UPTIME_KUMA_*` names are read, it is sent only to an allowed host, over https unless the host is local or plain http is allowed, and redirects are not followed.
- Theming through `--rubylode-uptime-kuma-*` custom properties, with dark mode.
- A demo with a fake Kuma (`ruby bin/demo up`) and README screenshots.

[Unreleased]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v0.2.0...main
[0.2.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rubylode/redmine-rubylode-uptime-kuma/releases/tag/v0.1.0

# Roadmap

## Goal

Show the status of a curated list of services inside Redmine, from Uptime Kuma, without storing the token and without breaking a page when Kuma is down.

## Done

- Block with down-first ordering, unknown state, summary, response times, fallback and caching.
- Wiki macro, page, My page block, partial.
- Settings with validation, host-bound token, https rule, no redirects.
- Placements: the welcome page, My page, the project Overview, listed paths and a top menu link.
- Rubylode plugin standard: one set of setting names and wording, the page at `/status/uptime_kuma`, and a widget on the Rubylode Status page.
- Demo with a fake Kuma, tests, screenshots.

## Ideas, not decided

- Several Kuma instances or several named lists.
- Translations beyond English.
- Uptime percentages or a short history, if asked for. Out of scope so far: alerts and a public status page.

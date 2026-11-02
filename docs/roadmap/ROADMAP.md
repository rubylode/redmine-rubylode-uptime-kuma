# Roadmap

## Goal

Show the live status of a curated list of services inside Redmine, from Uptime Kuma, without storing the token and without breaking a page when Kuma is down.

## Done (0.1.0)

- Block with down-first ordering, unknown state, summary, response times, fallback and caching.
- Wiki macro, page, My page block, partial.
- Settings with validation, host-bound token, https rule, no redirects.
- Demo with a fake Kuma, tests, screenshots.

## Ideas, not decided

- Several Kuma instances or several named lists.
- Translations beyond English.
- Uptime percentages or a short history, if asked for. Out of scope so far: alerts and a public status page.

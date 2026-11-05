# Listing on www.redmine.org

The text to paste at www.redmine.org, Plugins, New plugin. Redmine's "Check for updates" asks that directory about every installed plugin, so the listing must carry the same name, author and version as the plugin.

| Field | Value |
|---|---|
| Name | Rubylode Uptime Kuma |
| Short description | Shows the status of chosen services from Uptime Kuma, as a wiki macro, a page, a My page block and a partial |
| Homepage | https://github.com/rubylode/redmine-rubylode-uptime-kuma |
| Compatible with | Redmine 5.1.x, 6.0.x, 6.1.x, 7.0.x |
| License | GNU General Public License, version 2 or (at your option) any later version |
| Author | Rubylode |

## Notes for the current version

Version 2.1.0. Shows the status of chosen services from Uptime Kuma, as a wiki macro, a page, a My page block and a partial. Needs Redmine 5.1 or newer. Shows on the Status page of Rubylode Status when that plugin is installed. Install and settings are described in the README at https://github.com/rubylode/redmine-rubylode-uptime-kuma.

## File to upload

`redmine_rubylode_uptime_kuma-2.1.0.zip`, the file the GitHub release workflow publishes when a `v2.0.0` tag is pushed. Upload the same file that is attached to the GitHub release.

## Checking the result

The name, author and version in the listing must match what the plugin registers (`Rubylode Uptime Kuma`, `Rubylode`, `2.0.0`). When they do, Administration, Plugins, Check for updates shows:

- a green tick: the installed version is the latest one listed on redmine.org;
- an amber warning: redmine.org lists a newer version than the installed one;
- a grey question mark: the plugin is not found, so the name or the listing needs a look.

The answer comes only from the redmine.org directory. Nothing in the plugin can change it, and it stays grey until the listing exists.

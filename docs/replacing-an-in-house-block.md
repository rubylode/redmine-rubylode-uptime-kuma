# Replacing an in-house status block

If your Redmine already has a hand-made block that reads Uptime Kuma's `/metrics` (a plugin with a hard-coded service list, a token read from the environment, a partial on the home page), this plugin does the same job from settings. The switch takes four steps and can be done one page at a time.

1. Set the token variable. Put the Kuma API key in the environment of the Redmine process as `UPTIME_KUMA_API_TOKEN`, the same way the old block got its key. If the old block used another name, rename it: only names starting with `UPTIME_KUMA_` are read. Restart Redmine so it sees the variable.
2. Install the plugin and fill in the settings. Administration, Plugins, Rubylode Uptime Kuma, Configure. Enter the metrics URL (https, or tick "Allow plain http" for an internal address) and move the old list into the services textarea, one line per service: `Name | URL | Description | Kuma monitor name`. The old list's four fields map straight onto these. Add the dashboard link if response times used to link somewhere, and copy the old cache and timeout values if they were not the defaults (60, 30 and 2 seconds).
3. Put the block where the old one was. If the old block was a hook on the welcome page (the usual way to add a block to Home), this is now a direct replacement: tick "The welcome page (Home)" under "Show the block on" and choose the same column. Other places:
   - A wiki page, news item or the welcome text: add `{{service_status}}`. A view that rendered the old partial directly can call `render partial: "rubylode_uptime_kuma/service_status"` instead.
   - My page, the project Overview, or any page by path: the same "Show the block on" section.
   - Or link to `/service_status`, with the top menu link if you like.
4. Retire the old block. Once the new one shows the same rows, remove the old partial, its hook and its stylesheet rules, and unregister or uninstall the old plugin code. The old cache entries expire on their own.

Things that behave the same: only listed services appear, down ones first, a service with no matching monitor shows as unknown and is left out of the count, response times link to the dashboard, and a Kuma outage shows "Status unavailable" without breaking the page.

Things that differ: the list and the cache times now live in plugin settings instead of code, the token variable name is restricted, the token is only sent over https (or to this machine) and only to the host of the metrics URL, and redirects are not followed. Check these if the old block reached Kuma in a way the new rules refuse; the block then shows "Status unavailable" and administrators see the reason beneath it.

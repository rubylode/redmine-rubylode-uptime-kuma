# Rubylode Uptime Kuma: a live service status block for Redmine
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Demo data for trying the status block: one person, one project with a wiki page that uses the macro, the plugin settings
# pointing at the fake Kuma (test/support/fake_kuma_server.rb) and a My page with the block. Everything is made up.
# Only for the throwaway Redmine in docker-compose.yml. Safe to run twice.
#
#   ruby bin/demo up        (runs this script)

DEMO_PASSWORD = "demo-password-1".freeze
DEMO_SERVICES = <<~TEXT.freeze
  Website | https://www.example.com | The public site | Website homepage
  Billing | https://billing.example.com | Invoices and payments | Billing app health
  Wiki | https://wiki.example.com | Internal notes | Wiki
  Support desk | https://support.example.com | Customer questions | Support desk
  Reports | https://reports.example.com | Monthly numbers | Reports app
TEXT

User.current = User.find_by!(login: "admin")
admin = User.current
admin.password = admin.password_confirmation = "admin"
admin.must_change_passwd = false
admin.save!(validate: false)

Setting.default_language = "en"
Setting.send(:"plugin_redmine_rubylode_uptime_kuma=",
             RedmineRubylodeUptimeKuma::Defaults::SETTINGS.merge(
               "metrics_url" => "http://fake_kuma:9100/metrics",
               "allow_plain_http" => "1", # the fake Kuma is on the compose network over plain http
               "services" => DEMO_SERVICES,
               "dashboard_url" => "https://uptime.example.com/dashboard",
               "show_on_welcome_page" => "1",
               "show_in_top_menu" => "1",
               "cache_seconds" => "1",
               "failure_cache_seconds" => "1"
             ))

role = Role.find_or_initialize_by(name: "Demo member")
role.permissions = %i[view_wiki_pages view_issues] if role.new_record?
role.save!

sam = User.find_or_initialize_by(login: "sam.rivera")
if sam.new_record?
  sam.assign_attributes(firstname: "Sam", lastname: "Rivera", mail: "sam.rivera@example.com", language: "en",
                        password: DEMO_PASSWORD, password_confirmation: DEMO_PASSWORD, must_change_passwd: false)
  sam.save!
end

project = Project.find_or_initialize_by(identifier: "demo-project")
if project.new_record?
  project.name = "Demo project"
  project.is_public = false
  project.enabled_module_names = %w[wiki issue_tracking]
  project.save!
end
Member.find_or_create_by!(project: project, user: sam) { |member| member.roles = [role] }

project.create_wiki(start_page: "Wiki") unless project.wiki
page = project.wiki.find_or_new_page("Wiki")
page.content ||= WikiContent.new
page.content.text = "h1. Welcome\n\nWhere we stand right now:\n\n{{service_status}}\n"
page.content.author = admin
page.save!

preference = sam.pref
preference.my_page_layout = { "top" => ["rubylode_service_status"] }
preference.save!

puts "Demo data ready. Sign in as sam.rivera / #{DEMO_PASSWORD} or admin / admin."

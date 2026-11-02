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

require "redmine"
require_relative "lib/redmine_rubylode_uptime_kuma/defaults"

Redmine::Plugin.register :redmine_rubylode_uptime_kuma do
  name "Rubylode Uptime Kuma"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  description "A live service status block from Uptime Kuma: a wiki macro, a page, a My page block and a partial"
  version "0.2.0"
  requires_redmine version_or_higher: "7.0.0"

  menu :top_menu, :rubylode_service_status, { controller: "rubylode_service_status", action: "show" },
       caption: :"rubylode_uptime_kuma.page_title",
       if: proc {
         configuration = RubylodeUptimeKuma::Configuration.current
         configuration.show_in_top_menu? && configuration.configured? && configuration.visible_to?(User.current)
       }

  settings default: RedmineRubylodeUptimeKuma::Defaults::SETTINGS, partial: "settings/rubylode_uptime_kuma"
end

require_relative "lib/redmine_rubylode_uptime_kuma/macros"
RedmineRubylodeUptimeKuma::Macros.register
require_relative "lib/redmine_rubylode_uptime_kuma/default_layout_patch"
Redmine::MyPage.singleton_class.prepend RedmineRubylodeUptimeKuma::DefaultLayoutPatch unless Redmine::MyPage.singleton_class.include?(RedmineRubylodeUptimeKuma::DefaultLayoutPatch)
require_relative "lib/redmine_rubylode_uptime_kuma/hooks"
require_relative "lib/redmine_rubylode_uptime_kuma/settings_controller_patch"

# Plugins load after the boot-time prepare callbacks have run, so apply the patch now and again after each code reload.
apply_settings_controller_patch = lambda do
  unless SettingsController.include?(RedmineRubylodeUptimeKuma::SettingsControllerPatch)
    SettingsController.prepend RedmineRubylodeUptimeKuma::SettingsControllerPatch
  end
end
apply_settings_controller_patch.call
Rails.configuration.to_prepare(&apply_settings_controller_patch)

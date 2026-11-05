# Rubylode Uptime Kuma: the status of your services in Redmine
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

Redmine::Plugin.register :redmine_rubylode_uptime_kuma do
  name "Rubylode Uptime Kuma"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  url "https://github.com/rubylode/redmine-rubylode-uptime-kuma"
  description "Shows the status of chosen services from Uptime Kuma, as a wiki macro, a page, a My page block and a partial"
  version "2.1.0"
  requires_redmine version_or_higher: "5.1.0"

  # With Rubylode Status installed the block lives on its Status page, so this plugin drops its own top menu item.
  menu :top_menu, :rubylode_uptime_kuma_status, { controller: "rubylode_uptime_kuma_status", action: "show" },
       caption: proc { RubylodeUptimeKuma::Settings.current.block_title },
       if: proc {
         settings = RubylodeUptimeKuma::Settings.current
         !RubylodeUptimeKuma::Settings.status_plugin_installed? &&
           settings.show_in_top_menu? && settings.configured? && settings.visible_to?(User.current)
       }

  settings default: RubylodeUptimeKuma::Settings::DEFAULTS, partial: "settings/rubylode_uptime_kuma"
end

RubylodeUptimeKuma::Hooks # loaded so Redmine registers the view hooks
RubylodeUptimeKuma::Macros.register
Redmine::MyPage.singleton_class.prepend RubylodeUptimeKuma::DefaultLayoutPatch unless Redmine::MyPage.singleton_class.include?(RubylodeUptimeKuma::DefaultLayoutPatch)

# Plugins load after the boot-time prepare callbacks have run, so apply the patch now and again after each code reload.
apply_settings_controller_patch = lambda do
  unless SettingsController.include?(RubylodeUptimeKuma::SettingsControllerPatch)
    SettingsController.prepend RubylodeUptimeKuma::SettingsControllerPatch
  end
end
apply_settings_controller_patch.call
Rails.configuration.to_prepare(&apply_settings_controller_patch)

# Puts the block on the Status page when Rubylode Status is installed. See its docs/widget-contract.md.
Rails.application.config.after_initialize do
  RubylodeUptimeKuma::StatusWidget.register
end

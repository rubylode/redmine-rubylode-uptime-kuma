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

# Version 2.0.0 asks for the Uptime Kuma address and adds /metrics itself, so the saved "metrics_url" becomes "base_url"
# without its trailing /metrics. Going back adds /metrics again.
class RenameKumaSettingsForVersionTwo < ActiveRecord::Migration[6.1]
  SETTING_NAME = "plugin_redmine_rubylode_uptime_kuma".freeze
  METRICS_SUFFIX = "/metrics".freeze

  def up
    rewrite_saved_settings do |saved|
      if saved.key?("metrics_url")
        address = saved.delete("metrics_url").to_s.strip
        saved["base_url"] = address.chomp("/").delete_suffix(METRICS_SUFFIX) unless saved.key?("base_url")
      end
    end
  end

  def down
    rewrite_saved_settings do |saved|
      if saved.key?("base_url")
        address = saved.delete("base_url").to_s.strip.chomp("/")
        saved["metrics_url"] = address.empty? ? "" : "#{address}#{METRICS_SUFFIX}"
      end
    end
  end

  private

  def rewrite_saved_settings
    return unless Setting.where(name: SETTING_NAME).exists?

    saved = Setting.send(SETTING_NAME).to_h.stringify_keys
    return if saved.empty?

    yield saved
    Setting.send(:"#{SETTING_NAME}=", saved)
  end
end

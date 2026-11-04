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

require_relative "../test_helper"
require File.expand_path("../../db/migrate/001_rename_settings_for_version_two", __dir__)

class RubylodeUptimeKuma::RenameSettingsMigrationTest < ActiveSupport::TestCase
  SETTING_NAME = "plugin_redmine_rubylode_uptime_kuma".freeze

  setup do
    Setting.where(name: SETTING_NAME).delete_all
    Setting.clear_cache
  end

  teardown do
    Setting.where(name: SETTING_NAME).delete_all
    Setting.clear_cache
  end

  def save(settings)
    Setting.send(:"#{SETTING_NAME}=", settings)
  end

  def saved
    Setting.clear_cache
    Setting.send(SETTING_NAME)
  end

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { RenameSettingsForVersionTwo.new.migrate(direction) }
  end

  test "up turns the metrics url into the address, without /metrics, and keeps the rest" do
    save("metrics_url" => "https://uptime.example.com/metrics", "block_title" => "Our services", "show_on_my_page" => "1")
    migrate(:up)

    assert_equal "https://uptime.example.com", saved["base_url"]
    assert_equal "Our services", saved["block_title"]
    assert_equal "1", saved["show_on_my_page"]
    refute saved.key?("metrics_url")
  end

  test "up keeps a path before /metrics and drops a trailing slash" do
    save("metrics_url" => "http://kuma.internal.example.com:3001/status/metrics/")
    migrate(:up)

    assert_equal "http://kuma.internal.example.com:3001/status", saved["base_url"]
  end

  test "up leaves an empty address empty" do
    save("metrics_url" => "", "block_title" => "Services")
    migrate(:up)

    assert_equal "", saved["base_url"]
  end

  test "up does not overwrite an address that is already under the new key" do
    save("metrics_url" => "https://old.example.com/metrics", "base_url" => "https://new.example.com")
    migrate(:up)

    assert_equal "https://new.example.com", saved["base_url"]
    refute saved.key?("metrics_url")
  end

  test "up writes nothing when no settings were saved" do
    migrate(:up)

    refute Setting.where(name: SETTING_NAME).exists?
  end

  test "down gives the address its /metrics back" do
    save("base_url" => "https://uptime.example.com", "block_title" => "Services")
    migrate(:down)

    assert_equal "https://uptime.example.com/metrics", saved["metrics_url"]
    assert_equal "Services", saved["block_title"]
    refute saved.key?("base_url")
  end

  test "down keeps an empty address empty" do
    save("base_url" => "")
    migrate(:down)

    assert_equal "", saved["metrics_url"]
  end

  test "down writes nothing when no settings were saved" do
    migrate(:down)

    refute Setting.where(name: SETTING_NAME).exists?
  end

  test "up and then down gives back the saved address" do
    save("metrics_url" => "https://uptime.example.com/metrics")
    migrate(:up)
    migrate(:down)

    assert_equal "https://uptime.example.com/metrics", saved["metrics_url"]
  end
end

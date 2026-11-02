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

require_relative "../test_helper"

class RubylodeUptimeKuma::ConfigurationTest < ActiveSupport::TestCase
  def configuration(settings = {})
    RubylodeUptimeKuma::Configuration.new(settings)
  end

  test "a fresh install is not configured and has the documented defaults" do
    fresh = configuration({})

    refute fresh.configured?
    assert_equal "", fresh.metrics_url
    assert_equal "UPTIME_KUMA_API_TOKEN", fresh.token_environment_variable
    assert_equal [60, 30, 2], [fresh.cache_seconds, fresh.failure_cache_seconds, fresh.timeout_seconds]
    assert fresh.show_response_time?
    assert_equal "Services", fresh.block_title
    assert_equal "logged_in", fresh.visibility
  end

  test "the defaults name no company and no address" do
    assert_equal "", RedmineRubylodeUptimeKuma::Defaults::SETTINGS["metrics_url"]
    assert_equal "", RedmineRubylodeUptimeKuma::Defaults::SETTINGS["services"]
  end

  test "it is configured with a metrics url and at least one valid service" do
    assert configuration("metrics_url" => "https://k.example.com/metrics", "services" => "A | https://a.example.com | x | A").configured?
    refute configuration("metrics_url" => "https://k.example.com/metrics", "services" => "").configured?
    refute configuration("metrics_url" => "", "services" => "A | https://a.example.com | x | A").configured?
  end

  test "bad numbers fall back to the defaults and small ones are raised to the minimum" do
    assert_equal 60, configuration("cache_seconds" => "abc").cache_seconds
    assert_equal 1, configuration("timeout_seconds" => "0").timeout_seconds
    assert_equal 0, configuration("cache_seconds" => "-3").cache_seconds
  end

  test "an invalid token variable name falls back to the default name" do
    assert_equal "UPTIME_KUMA_MINE", configuration("token_environment_variable" => " UPTIME_KUMA_MINE ").token_environment_variable
  end

  test "a variable outside the UPTIME_KUMA_ family is ignored: no name, no token, ENV is never read for it" do
    names = ["SECRET_KEY_BASE", "DATABASE_PASSWORD", "uptime_kuma_lowercase", "not valid", "UPTIME_KUMA"]
    originals = names.to_h { |name| [name, ENV[name]] }
    names.each { |name| ENV[name] = "should-never-be-read" }

    names.each do |name|
      settings = configuration("token_environment_variable" => name)

      assert_nil settings.token_environment_variable, name
      assert_equal "", settings.token, name
    end
  ensure
    originals.each { |name, value| value ? ENV[name] = value : ENV.delete(name) }
  end

  test "allowed hosts are read as a list and plain http is off by default" do
    settings = configuration("allowed_hosts" => "Kuma.Example.com, backup.example.com\nother.example.com")

    assert_equal %w[kuma.example.com backup.example.com other.example.com], settings.allowed_hosts
    assert_empty configuration({}).allowed_hosts
    refute configuration({}).allow_plain_http?
    assert configuration("allow_plain_http" => "1").allow_plain_http?
  end

  test "visibility: signed-in users by default, administrators when asked, never anonymous" do
    member = User.generate!
    administrator = User.generate! { |user| user.admin = true }

    open_to_users = configuration("visibility" => "logged_in")
    assert open_to_users.visible_to?(member)
    refute open_to_users.visible_to?(User.anonymous)

    admins_only = configuration("visibility" => "admins")
    refute admins_only.visible_to?(member)
    assert admins_only.visible_to?(administrator)
  end

  test "the welcome page block is off by default, on the right, and an unknown column means right" do
    refute configuration({}).show_on_welcome_page?
    assert_equal "right", configuration({}).welcome_page_column
    assert configuration("show_on_welcome_page" => "1").show_on_welcome_page?
    assert_equal "left", configuration("welcome_page_column" => "left").welcome_page_column
    assert_equal "right", configuration("welcome_page_column" => "middle").welcome_page_column
  end

test "the other placements are off by default and read their settings" do
    fresh = configuration({})
    refute fresh.show_on_my_page?
    refute fresh.show_on_project_overview?
    refute fresh.show_on_matching_pages?
    refute fresh.show_in_top_menu?
    assert_equal "right", fresh.project_overview_column
  
    custom = configuration("show_on_matching_pages" => "1", "matching_page_paths" => "# x\n/issues\n/news")
    assert custom.show_on_matching_pages?
    assert_equal ["/issues", "/news"], custom.matching_page_paths
    refute configuration("show_on_matching_pages" => "1", "matching_page_paths" => "").show_on_matching_pages?, "ticked but no paths"
  end
  
  test "an unknown visibility value is treated as signed-in users" do
    assert_equal "logged_in", configuration("visibility" => "whatever").visibility
  end
end

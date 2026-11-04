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

# The settings page and the plugin's page as the Rubylode plugin standard words them, with and without the Status plugin.
class RubylodeUptimeKuma::StatusPluginAndWordingTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  SETTINGS_PATH = "/settings/plugin/redmine_rubylode_uptime_kuma".freeze

  setup do
    use_memory_cache
    configure_plugin("show_in_top_menu" => "1")
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0 }))
  end

  teardown do
    restore_cache
  end

  test "every setting has the label of the standard" do
    log_user("admin", "admin")
    get SETTINGS_PATH

    {
      "settings_base_url" => "Uptime Kuma address",
      "settings_token_environment_variable" => "Token variable",
      "settings_allowed_hosts" => "Allowed hosts",
      "settings_allow_plain_http" => "Allow plain http",
      "settings_services" => "Services",
      "settings_dashboard_url" => "Dashboard link",
      "settings_block_title" => "Block title",
      "settings_visibility" => "Who may see the block",
      "settings_cache_seconds" => "Cache seconds",
      "settings_failure_cache_seconds" => "Failure cache seconds",
      "settings_timeout_seconds" => "Timeout seconds"
    }.each do |field_id, label|
      assert_select "label[for=?]", field_id, text: label
    end
    assert_select "fieldset.rubylode-uptime-kuma-placements legend", text: "Show the block on"
    [["Welcome page", "show_on_welcome_page"], ["My page", "show_on_my_page"], ["Project Overview page", "show_on_project_overview"],
     ["Pages matching these paths", "show_on_matching_pages"], ["Show in the top menu", "show_in_top_menu"]].each do |label, key|
      assert_select "fieldset label.floating", text: /#{Regexp.escape(label)}/
      assert_select "input[type=checkbox][name=?]", "settings[#{key}]"
    end
  end

  test "each column select has a visible label" do
    log_user("admin", "admin")
    get SETTINGS_PATH

    %w[welcome_page_column project_overview_column].each do |key|
      assert_select "label[for=settings_#{key}]", text: "Column"
      assert_select "select#settings_#{key}"
    end
  end

  test "the hints are the sentences of the standard" do
    log_user("admin", "admin")
    get SETTINGS_PATH

    assert_select "em.info", text: /\AThe name of the environment variable that holds the API token\. The token is never saved here\. Set it before Redmine starts\. The name must start with UPTIME_KUMA_\.\s+not set in the environment\z/
    assert_select "em.info", text: "Check this only when the service is on a network you trust. The credentials then travel unencrypted."
    assert_select "em.info", text: "Adds a link to /status/uptime_kuma to the top menu, for the people who may see the block."
    assert_select "em.info", text: "One service per line: Name | URL | Description | Kuma monitor name. Lines starting with # are ignored."
    assert_select "em.info", text: "A request to Uptime Kuma is given up after this many seconds."
    assert_no_match(/translation missing/i, response.body)
  end

  test "without the Status plugin the settings page offers the top menu setting and links to Rubylode Status" do
    log_user("admin", "admin")
    get SETTINGS_PATH

    assert_select "input[type=checkbox][name=?]", "settings[show_in_top_menu]"
    assert_select "p.rubylode-status-notice", text: "Install Rubylode Status to see this with the other status blocks on one page."
    assert_select "p.rubylode-status-notice a[href=?]", "https://github.com/rubylode/redmine-rubylode-status", text: "Rubylode Status"
  end

  test "with the Status plugin the settings page hides the top menu setting, keeps its value and says where the block is" do
    with_status_plugin_registry do
      log_user("admin", "admin")
      get SETTINGS_PATH

      assert_select "input[type=checkbox][name=?]", "settings[show_in_top_menu]", 0
      assert_select "input[type=hidden][name=?][value=?]", "settings[show_in_top_menu]", "1"
      assert_select "p.rubylode-status-notice", text: "Rubylode Status is installed, so this block shows on the Status page."
      assert_select "p.rubylode-status-notice a[href=?]", "/status", text: "Status page"
    end
  end

  test "the plugin's own page carries the notice in both cases" do
    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"
    assert_select "p.rubylode-status-notice", text: "Install Rubylode Status to see this with the other status blocks on one page."

    with_status_plugin_registry do
      get "/status/uptime_kuma"
      assert_response :success
      assert_select "p.rubylode-status-notice", text: "Rubylode Status is installed, so this block shows on the Status page."
    end
  end

  test "the top menu link is named like the block title and goes when the Status plugin is installed" do
    configure_plugin("show_in_top_menu" => "1", "block_title" => "Our services")
    log_user("jsmith", "jsmith")
    get "/issues"
    assert_select "#top-menu a[href=?]", "/status/uptime_kuma", text: "Our services"

    with_status_plugin_registry do
      get "/issues"
      assert_select "#top-menu a[href=?]", "/status/uptime_kuma", 0
    end
  end
end

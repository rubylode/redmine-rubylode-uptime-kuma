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

class RubylodeUptimeKuma::ServiceStatusPageTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issue_statuses, :trackers, :projects_trackers, :enumerations, :enabled_modules

  setup do
    use_memory_cache
    configure_plugin
  end

  teardown do
    restore_cache
  end

  test "the old page address redirects to the new one with a 301" do
    log_user("jsmith", "jsmith")
    get "/service_status"

    assert_response :moved_permanently
    assert_redirected_to "/status/uptime_kuma"
  end

  test "the page is named for the short name" do
    assert_equal "/status/uptime_kuma", Rails.application.routes.url_helpers.rubylode_uptime_kuma_status_path
  end

  test "the page shows a table of services with description, status and response time, down ones first" do
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0 }, "Website homepage" => 142))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_response :success
    assert_select ".rubylode-service-status-summary", text: "1 of 2 down"
    assert_select ".rubylode-service-status-table th", text: "Response time"
    assert_select "tbody tr:first-child.is-down td.rubylode-service-status-name a[href=?]", "https://billing.example.com", text: "Billing"
    assert_select "tr.is-up td.rubylode-service-status-description", text: "The public site"
    assert_select "tr.is-up td.rubylode-service-status-state", text: "Up"
    assert_select "tr.is-down td.rubylode-service-status-state", text: "Down"
    assert_select "tr.is-up td.rubylode-service-status-response-time a[href=?]", "https://kuma.example.com/dashboard", text: "142 ms"
    assert_select "tr.is-unknown td.rubylode-service-status-name a", text: "Wiki"
    assert_select "tr.is-unknown td.rubylode-service-status-state", text: "Unknown"
  end

  test "every monitor up gives the all-up summary and no down rows" do
    publish_metrics(metrics_text("Website homepage" => 1, "Billing app health" => 1, "Wiki" => 1))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-summary.is-all-up", text: "All services up"
    assert_select "tr.is-down", 0
    assert_select "tr.is-unknown", 0
  end

  test "a monitor that is not on the curated list does not appear" do
    publish_metrics(metrics_text("Website homepage" => 1, "Vendor login (external)" => 0))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-table", text: /Vendor login/, count: 0
    assert_select ".rubylode-service-status-summary", text: "All services up"
  end

  test "a response time of minus one shows a dash and not a number" do
    publish_metrics(metrics_text({ "Website homepage" => 0 }, "Website homepage" => -1))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select "tr.is-down td.rubylode-service-status-response-time", text: "–"
  end

  test "without a dashboard link the response time is plain text" do
    configure_plugin("dashboard_url" => "")
    publish_metrics(metrics_text({ "Website homepage" => 1 }, "Website homepage" => 142))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select "td.rubylode-service-status-response-time", text: /142 ms/
    assert_select "td.rubylode-service-status-response-time a", 0
  end

  test "the response time column can be switched off" do
    configure_plugin("show_response_time" => "0")
    publish_metrics(metrics_text({ "Website homepage" => 1 }, "Website homepage" => 142))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-table th", text: "Response time", count: 0
    assert_select "td.rubylode-service-status-response-time", 0
  end

  test "the block title is the setting" do
    configure_plugin("block_title" => "Company services")
    publish_metrics(metrics_text("Website homepage" => 1))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select "h2", text: "Company services"
  end

  test "when Kuma gives no answer the page still renders with status unavailable" do
    RubylodeUptimeKuma::ServiceStatus.cache.write(
      RubylodeUptimeKuma::ServiceStatus.cache_key_for("https://kuma.example.com/metrics"), "kuma-unavailable|Kuma answered 503"
    )

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_response :success
    assert_select ".rubylode-service-status-summary.is-unavailable", text: "Status unavailable"
    assert_select ".rubylode-service-status-table", 0
    assert_select ".rubylode-service-status-hint", 0, "the reason is for administrators only"
  end

  test "an administrator sees why the status is unavailable" do
    RubylodeUptimeKuma::ServiceStatus.cache.write(
      RubylodeUptimeKuma::ServiceStatus.cache_key_for("https://kuma.example.com/metrics"), "kuma-unavailable|Kuma answered 503"
    )

    log_user("admin", "admin")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-hint", text: /Kuma answered 503/
  end

  test "a missing token shows status unavailable and the page renders" do
    ENV.delete("UPTIME_KUMA_API_TOKEN")
    configure_plugin("base_url" => "http://127.0.0.1:9")

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_response :success
    assert_select ".rubylode-service-status-summary", text: "Status unavailable"
  end

  test "not configured: administrators get a hint with a link to the settings, everyone else gets an empty page" do
    configure_plugin("base_url" => "")

    log_user("admin", "admin")
    get "/status/uptime_kuma"
    assert_select ".rubylode-service-status-hint a[href=?]", "/settings/plugin/redmine_rubylode_uptime_kuma"

    post "/logout"
    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"
    assert_response :success
    assert_select ".rubylode-service-status", 0
  end

  test "an anonymous visitor is sent to sign in" do
    get "/status/uptime_kuma"

    assert_redirected_to %r{/login}
  end

  test "the stylesheet is linked from the page head" do
    publish_metrics(metrics_text("Website homepage" => 1))

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select "head link[href*=?]", "rubylode_uptime_kuma"
  end
end

class RubylodeUptimeKuma::ServiceStatusPermissionTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issue_statuses, :trackers, :projects_trackers, :enumerations, :enabled_modules

  setup do
    use_memory_cache
    publish_metrics(metrics_text("Website homepage" => 1))
  end

  teardown do
    restore_cache
  end

  test "by default every signed-in user may see the page" do
    configure_plugin

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_response :success
    assert_select ".rubylode-service-status-table"
  end

  test "set to administrators only, a signed-in user is refused and an administrator is not" do
    configure_plugin("visibility" => "admins")

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"
    assert_response :forbidden

    post "/logout"
    log_user("admin", "admin")
    get "/status/uptime_kuma"
    assert_response :success
    assert_select ".rubylode-service-status-table"
  end
end

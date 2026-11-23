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

class RubylodeUptimeKuma::SourceLinkTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issue_statuses, :trackers, :projects_trackers, :enumerations, :enabled_modules

  LINK = "a.rubylode-uptime-kuma-source-link".freeze
  METRICS_URL = "https://kuma.example.com/metrics".freeze

  setup do
    use_memory_cache
    configure_plugin
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0 }, "Website homepage" => 142))
  end

  teardown do
    User.current = nil
    restore_cache
  end

  def publish_unavailable
    RubylodeUptimeKuma::ServiceStatus.cache.write(RubylodeUptimeKuma::ServiceStatus.cache_key_for(METRICS_URL), "kuma-unavailable|Kuma answered 503")
  end

  test "the page has an Open Uptime Kuma link to the dashboard address, before the table" do
    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_response :success
    assert_select "#{LINK}[href=?][class~=external]", "https://kuma.example.com/dashboard", text: "Open Uptime Kuma"
    assert_select "#{LINK}[target]", 0
    assert_select ".rubylode-service-status > #{LINK} + .rubylode-service-status-table"
  end

  test "without a dashboard link the base address is opened" do
    configure_plugin("dashboard_url" => "")

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select "#{LINK}[href=?]", "https://kuma.example.com"
  end

  test "the link follows the summary line" do
    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-summary + #{LINK}"
  end

  test "the link shows when Kuma cannot be reached" do
    publish_unavailable

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-summary.is-unavailable", text: "Status unavailable"
    assert_select LINK, text: "Open Uptime Kuma"
  end

  test "the link shows in the compact block" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/issues")

    log_user("jsmith", "jsmith")
    get "/issues"

    assert_select ".rubylode-service-status.is-compact #{LINK}[href=?]", "https://kuma.example.com/dashboard"
  end

  test "the link is drawn inside the Status page widget, which draws no title or summary" do
    User.current = User.find_by_login("jsmith")
    html = ApplicationController.render(partial: "rubylode_uptime_kuma/status", locals: { widget: Object.new, status: nil })
    page = Nokogiri::HTML.fragment(html)

    assert_equal 0, page.css(".rubylode-service-status-summary").size
    assert_equal ["Open Uptime Kuma"], page.css(LINK).map(&:text)
  end

  test "there is no link while the plugin is not set up, not even for an administrator" do
    configure_plugin("base_url" => "", "services" => "")

    log_user("admin", "admin")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-hint"
    assert_select LINK, 0
  end

  test "there is no link for a person the block is hidden from" do
    configure_plugin("visibility" => "admins")

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select LINK, 0
  end

  test "an address that is not a web address draws no link" do
    configure_plugin("dashboard_url" => "javascript:alert(1)", "base_url" => "https://kuma.example.com")

    log_user("jsmith", "jsmith")
    get "/status/uptime_kuma"

    assert_select LINK, 0
  end
end

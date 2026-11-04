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

class RubylodeUptimeKuma::WelcomePageTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :news

  BLOCK = ".rubylode-service-status".freeze

  setup do
    use_memory_cache
    configure_plugin("show_on_welcome_page" => "1")
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0 }, "Website homepage" => 142))
  end

  teardown do
    restore_cache
  end

  test "the block is not on the welcome page unless the setting is on" do
    configure_plugin("show_on_welcome_page" => "0")

    log_user("jsmith", "jsmith")
    get "/"

    assert_response :success
    assert_select BLOCK, 0
  end

test "the welcome text is rendered with Redmine's text formatting, so the macro works there without the setting" do
    configure_plugin("show_on_welcome_page" => "0")
    with_settings welcome_text: "Hello.\n\n{{uptime_kuma_status}}" do
      log_user("jsmith", "jsmith")
      get "/"
    end
  
    assert_select ".wiki #{BLOCK}-summary", text: "1 of 2 down"
  end
  
  test "with the setting on the block is in the right column by default" do
    log_user("jsmith", "jsmith")
    get "/"

    assert_response :success
    assert_select ".splitcontentright #{BLOCK} .rubylode-service-status-summary", text: "1 of 2 down"
    assert_select ".splitcontentleft #{BLOCK}", 0
    assert_select "head link[href*=?]", "rubylode_uptime_kuma"
  end

  test "the left column can be chosen" do
    configure_plugin("show_on_welcome_page" => "1", "welcome_page_column" => "left")

    log_user("jsmith", "jsmith")
    get "/"

    assert_select ".splitcontentleft #{BLOCK}"
    assert_select ".splitcontentright #{BLOCK}", 0
  end

  test "it uses the block title setting" do
    configure_plugin("show_on_welcome_page" => "1", "block_title" => "Company services")

    log_user("jsmith", "jsmith")
    get "/"

    assert_select "#{BLOCK} h3.rubylode-service-status-title", text: "Company services"
  end

  test "administrators only: an ordinary user gets nothing and an administrator gets the block" do
    configure_plugin("show_on_welcome_page" => "1", "visibility" => "admins")

    log_user("jsmith", "jsmith")
    get "/"
    assert_response :success
    assert_select BLOCK, 0

    post "/logout"
    log_user("admin", "admin")
    get "/"
    assert_select "#{BLOCK} .rubylode-service-status-table"
  end

  test "an anonymous visitor to the welcome page does not see the block" do
    get "/"

    assert_select BLOCK, 0
  end

  test "when Kuma gives no answer the welcome page still renders with status unavailable" do
    RubylodeUptimeKuma::ServiceStatus.cache.write(
      RubylodeUptimeKuma::ServiceStatus.cache_key_for("https://kuma.example.com/metrics"), "kuma-unavailable|Kuma answered 503"
    )

    log_user("jsmith", "jsmith")
    get "/"

    assert_response :success
    assert_select "#{BLOCK}-summary.is-unavailable", text: "Status unavailable"
  end

  test "not configured: administrators see the hint and everyone else sees nothing" do
    configure_plugin("show_on_welcome_page" => "1", "base_url" => "")

    log_user("admin", "admin")
    get "/"
    assert_select "#{BLOCK} .rubylode-service-status-hint a[href=?]", "/settings/plugin/redmine_rubylode_uptime_kuma"

    post "/logout"
    log_user("jsmith", "jsmith")
    get "/"
    assert_response :success
    assert_select BLOCK, 0
  end
end

class RubylodeUptimeKuma::WelcomePageKumaTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :news

  TOKEN = "welcome-sample-token-9d2e41".freeze
  TOKEN_VARIABLE = "UPTIME_KUMA_WELCOME_TEST_TOKEN".freeze

  setup do
    use_memory_cache
    @server = FakeKumaServer.new(token: TOKEN).start
    ENV[TOKEN_VARIABLE] = TOKEN
    configure_plugin("base_url" => @server.base_url, "token_environment_variable" => TOKEN_VARIABLE,
                     "show_on_welcome_page" => "1")
    @log_path = Rails.root.join("log", "#{Rails.env}.log")
    @log_offset = File.exist?(@log_path) ? File.size(@log_path) : 0
  end

  teardown do
    ENV.delete(TOKEN_VARIABLE)
    @server.stop
    restore_cache
  end

  test "Kuma is asked once across the welcome page and the status page within the cache window" do
    log_user("jsmith", "jsmith")
    get "/"
    get "/status/uptime_kuma"
    get "/"

    assert_select ".rubylode-service-status-summary", text: "All services up"
    assert_equal 1, @server.request_count
  end

  test "the token is not in the welcome page or the log" do
    log_user("jsmith", "jsmith")
    get "/"
    ENV[TOKEN_VARIABLE] = "wrong-welcome-token-33"
    RubylodeUptimeKuma::ServiceStatus.cache.clear
    get "/"

    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    log = File.open(@log_path) { |file| file.seek(@log_offset); file.read.to_s }
    [TOKEN, "wrong-welcome-token-33"].each do |secret|
      refute_includes response.body, secret
      refute_includes log, secret
    end
  end
end

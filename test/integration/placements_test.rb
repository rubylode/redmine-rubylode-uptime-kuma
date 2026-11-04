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

# The places the block can be put besides the macro, the page and the welcome page: each is present when its setting is
# on, absent when it is off, and hidden from a person the permission setting excludes.
class RubylodeUptimeKuma::PlacementsTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles, :issue_statuses,
           :trackers, :projects_trackers, :enumerations, :enabled_modules, :issues, :versions, :news

  BLOCK = ".rubylode-service-status".freeze

  setup do
    use_memory_cache
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0 }, "Website homepage" => 142))
  end

  teardown do
    restore_cache
  end

  # The project Overview page

  test "the project overview shows the block in the chosen column only when the setting is on" do
    configure_plugin("show_on_project_overview" => "0")
    log_user("jsmith", "jsmith")
    get "/projects/ecookbook"
    assert_select BLOCK, 0

    configure_plugin("show_on_project_overview" => "1", "project_overview_column" => "left")
    get "/projects/ecookbook"
    assert_select ".splitcontentleft #{BLOCK} .rubylode-service-status-summary", text: "1 of 2 down"
    assert_select ".splitcontentright #{BLOCK}", 0

    configure_plugin("show_on_project_overview" => "1", "project_overview_column" => "right")
    get "/projects/ecookbook"
    assert_select ".splitcontentright #{BLOCK}"
    assert_select ".splitcontentleft #{BLOCK}", 0
  end

  test "the project overview hides the block from a person the permission setting excludes" do
    configure_plugin("show_on_project_overview" => "1", "visibility" => "admins")
    log_user("jsmith", "jsmith")
    get "/projects/ecookbook"

    assert_response :success
    assert_select BLOCK, 0
  end

  # My page

  test "My page offers the block, and the default layout holds it only when the setting is on" do
    configure_plugin("show_on_my_page" => "0")
    refute_includes Redmine::MyPage.default_layout.values.flatten, "rubylode_uptime_kuma_status"

    configure_plugin("show_on_my_page" => "1")
    assert_includes Redmine::MyPage.default_layout["top"], "rubylode_uptime_kuma_status"
    assert_includes Redmine::MyPage.default_layout["left"], "issuesassignedtome", "Redmine's own blocks are kept"
  end

  test "a person with no layout of their own gets the block on My page when the setting is on" do
    configure_plugin("show_on_my_page" => "1")
    preference = User.find(2).pref
    preference.my_page_layout = nil
    preference.save!

    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select "#block-rubylode_uptime_kuma_status #{BLOCK}-summary", text: "1 of 2 down"
  end

  test "a person with no layout of their own does not get the block when the setting is off" do
    configure_plugin("show_on_my_page" => "0")
    preference = User.find(2).pref
    preference.my_page_layout = nil
    preference.save!

    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_response :success
    assert_select "#block-rubylode_uptime_kuma_status", 0
  end

  test "My page shows nothing in the block for a person the permission setting excludes" do
    configure_plugin("show_on_my_page" => "1", "visibility" => "admins")
    preference = User.find(2).pref
    preference.my_page_layout = nil
    preference.save!

    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select BLOCK, 0
  end

  # Pages on the path list

  test "a page on the path list gets the compact block under its content, other pages do not" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/issues\n/projects/*/issues")
    log_user("jsmith", "jsmith")

    get "/issues"
    assert_select "#content #{BLOCK}.is-compact #{BLOCK}-summary", text: "1 of 2 down"
    assert_select "#{BLOCK}.is-compact a.rubylode-service-status-compact-down[href=?]", "https://billing.example.com", text: "Billing"
    assert_select "#{BLOCK}-table", 0, "the compact form has no table"
    assert_select "head link[href*=?]", "rubylode_uptime_kuma"

    get "/issues?set_filter=1&status_id=o"
    assert_select "#{BLOCK}.is-compact"

    get "/projects/ecookbook/issues"
    assert_select "#{BLOCK}.is-compact"

    get "/news"
    assert_select BLOCK, 0
  end

  test "the path list does nothing when its setting is off or the list is empty" do
    configure_plugin("show_on_matching_pages" => "0", "matching_page_paths" => "/issues")
    log_user("jsmith", "jsmith")
    get "/issues"
    assert_select BLOCK, 0

    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "")
    get "/issues"
    assert_select BLOCK, 0
  end

  test "the path list hides the block from a person the permission setting excludes" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/issues", "visibility" => "admins")
    log_user("jsmith", "jsmith")
    get "/issues"

    assert_response :success
    assert_select BLOCK, 0
  end

  test "a wildcard list does not put the block on the sign-in page or the settings" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/**")

    get "/login"
    assert_response :success
    assert_select BLOCK, 0

    log_user("admin", "admin")
    get "/settings"
    assert_select BLOCK, 0
    get "/issues"
    assert_select BLOCK
  end

  test "the sign-in page can be listed explicitly but still shows nothing to anonymous visitors" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/login")

    get "/login"
    assert_select BLOCK, 0
  end

  # The top menu

  test "the top menu has a link, named like the block title, only when the setting is on and the person may see it" do
    configure_plugin("show_in_top_menu" => "0")
    log_user("jsmith", "jsmith")
    get "/issues"
    assert_select "#top-menu a[href=?]", "/status/uptime_kuma", 0

    configure_plugin("show_in_top_menu" => "1")
    get "/issues"
    assert_select "#top-menu a[href=?]", "/status/uptime_kuma", text: "Services"

    configure_plugin("show_in_top_menu" => "1", "visibility" => "admins")
    get "/issues"
    assert_select "#top-menu a[href=?]", "/status/uptime_kuma", 0
  end
end

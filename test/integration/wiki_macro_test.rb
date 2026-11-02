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

class RubylodeUptimeKuma::WikiMacroTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  setup do
    use_memory_cache
    configure_plugin
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0 }, "Website homepage" => 142))
  end

  teardown do
    restore_cache
  end

  def wiki_page_with(text)
    page = WikiPage.new(wiki: Project.find(1).wiki, title: "Status_#{SecureRandom.hex(3)}")
    page.content = WikiContent.new(text: text, author: User.find(2))
    page.save!
    page
  end

  def get_wiki_page(text, login: "jsmith")
    page = wiki_page_with(text)
    log_user(login, login)
    get "/projects/ecookbook/wiki/#{page.title}"
    assert_response :success
  end

  test "the macro draws the status block inside the wiki page" do
    get_wiki_page("Our services:\n\n{{service_status}}")

    assert_select ".wiki .rubylode-service-status-summary", text: "1 of 2 down"
    assert_select ".wiki tr.is-down td.rubylode-service-status-name", text: "Billing"
  end

  test "the second macro name draws the same block" do
    get_wiki_page("{{uptime_kuma_status}}")

    assert_select ".wiki .rubylode-service-status-table"
  end

  test "the macro takes a title" do
    get_wiki_page("{{service_status(title=Customer-facing)}}")

    assert_select ".wiki h3.rubylode-service-status-title", text: /\ACustomer-facing/
  end

  test "the macro uses the block title setting when it has no title" do
    configure_plugin("block_title" => "Company services")
    get_wiki_page("{{service_status}}")

    assert_select ".wiki h3.rubylode-service-status-title", text: /\ACompany services/
  end

  test "a person the permission setting excludes sees nothing where the macro stands" do
    configure_plugin("visibility" => "admins")
    get_wiki_page("before {{service_status}} after")

    assert_select ".wiki .rubylode-service-status", 0
    assert_select ".wiki", text: /before\s+after/
  end

  test "an AJAX render of the macro, such as the wiki preview, carries its own stylesheet link" do
    log_user("jsmith", "jsmith")
    post "/projects/ecookbook/wiki/Preview_target/preview", params: { text: "{{service_status}}" }, xhr: true

    assert_response :success
    assert_select "link[href*=?]", "rubylode_uptime_kuma"
    assert_select ".rubylode-service-status-table"
  end

  test "the macro is listed among the wiki macros" do
    assert Redmine::WikiFormatting::Macros.available_macros.key?(:service_status)
    assert Redmine::WikiFormatting::Macros.available_macros.key?(:uptime_kuma_status)
  end
end

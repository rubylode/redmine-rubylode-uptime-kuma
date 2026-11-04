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

class RubylodeUptimeKuma::PluginSettingsTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles

  SETTINGS_PATH = "/settings/plugin/redmine_rubylode_uptime_kuma".freeze

  GOOD_SETTINGS = {
    "base_url" => "https://uptime.example.com",
    "token_environment_variable" => "UPTIME_KUMA_MY_TOKEN",
    "services" => "Website | https://www.example.com | The site | Website homepage\nWiki | https://wiki.example.com | Notes | Wiki",
    "dashboard_url" => "https://uptime.example.com/dashboard",
    "cache_seconds" => "120", "failure_cache_seconds" => "15", "timeout_seconds" => "3",
    "allowed_hosts" => "uptime.example.com", "allow_plain_http" => "0",
    "show_response_time" => "0", "block_title" => "Our services", "visibility" => "admins",
    "show_on_welcome_page" => "1", "welcome_page_column" => "left"
  }.freeze

  setup do
    Setting.send(:"plugin_#{PLUGIN_ID}=", RubylodeUptimeKuma::Settings::DEFAULTS.dup)
  end

  test "the plugin is registered and its settings page opens with every field" do
    log_user("admin", "admin")
    get SETTINGS_PATH

    assert_response :success
    %w[base_url token_environment_variable allowed_hosts allow_plain_http services dashboard_url block_title visibility show_response_time
       show_on_welcome_page welcome_page_column
       cache_seconds failure_cache_seconds timeout_seconds].each do |field|
      assert_select "[name=?]", "settings[#{field}]"
    end
    assert_select "input[name=?][value=?]", "settings[token_environment_variable]", "UPTIME_KUMA_API_TOKEN"
  end

  test "good settings are saved as plugin settings" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS }

    assert_redirected_to SETTINGS_PATH
    saved = Setting.send(:"plugin_#{PLUGIN_ID}")
    assert_equal "https://uptime.example.com", saved["base_url"]
    assert_equal "UPTIME_KUMA_MY_TOKEN", saved["token_environment_variable"]
    assert_equal "admins", saved["visibility"]
    assert RubylodeUptimeKuma::Settings.current.show_on_welcome_page?
    assert_equal "left", RubylodeUptimeKuma::Settings.current.welcome_page_column
    assert_equal 2, RubylodeUptimeKuma::Settings.current.services.size
    refute RubylodeUptimeKuma::Settings.current.show_response_time?
  end

  test "a bad service line shows the line error, keeps what was typed and saves nothing" do
    log_user("admin", "admin")
    typed = "Website | https://www.example.com | The site | Website homepage\nbroken line here"
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("services" => typed) }

    assert_response :unprocessable_entity
    assert_select "#errorExplanation li", text: /line 2/
    assert_select "textarea[name=?]", "settings[services]", text: /broken line here/
    assert_equal "", Setting.send(:"plugin_#{PLUGIN_ID}")["base_url"], "nothing was saved"
  end

  test "an invalid metrics url and an invalid variable name are refused" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("base_url" => "ftp://nope", "token_environment_variable" => "not valid!") }

    assert_response :unprocessable_entity
    assert_select "#errorExplanation li", 2
  end

test "the placements are saved, with the path list" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("show_on_my_page" => "1", "show_on_project_overview" => "1",
                                                                 "project_overview_column" => "left", "show_on_matching_pages" => "1",
                                                                 "matching_page_paths" => "/issues\n/projects/*/issues", "show_in_top_menu" => "1") }
  
    assert_redirected_to SETTINGS_PATH
    saved = RubylodeUptimeKuma::Settings.current
    assert saved.show_on_my_page?
    assert_equal "left", saved.project_overview_column
    assert_equal ["/issues", "/projects/*/issues"], saved.matching_page_paths
    assert saved.show_in_top_menu?
  end
  
  test "a bad path is refused with its line number and nothing is saved" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("matching_page_paths" => "/issues\nhttps://example.com/x") }
  
    assert_response :unprocessable_entity
    assert_select "#errorExplanation li", text: /Paths, line 2/
    assert_select "textarea[name=?]", "settings[matching_page_paths]", text: %r{https://example.com/x}
    assert_equal "", Setting.send(:"plugin_#{PLUGIN_ID}")["base_url"]
  end
  
  test "the settings page explains how to show the block elsewhere, with the macro and the partial name" do
    log_user("admin", "admin")
    get SETTINGS_PATH
  
    assert_select "#rubylode-uptime-kuma-help h3", text: "How to show the block on other pages"
    assert_select "#rubylode-uptime-kuma-help tbody tr", 7
    assert_select "#rubylode-uptime-kuma-help", text: /\{\{uptime_kuma_status\}\}/
    assert_select "#rubylode-uptime-kuma-help", text: %r{rubylode_uptime_kuma/status}
    assert_select "#rubylode-uptime-kuma-help", text: %r{/status/uptime_kuma}
    assert_match(%r{<td>Yes</td>}, response.body)
    assert_match(%r{<td>No</td>}, response.body)
    assert_no_match(/translation missing/i, response.body)
    assert_select "fieldset.rubylode-uptime-kuma-placements input[type=checkbox]", 5
  end
  
  test "naming another secret as the token variable is refused at save" do
    log_user("admin", "admin")
    %w[SECRET_KEY_BASE DATABASE_PASSWORD].each do |name|
      post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("token_environment_variable" => name) }

      assert_response :unprocessable_entity
      assert_select "#errorExplanation li", text: /UPTIME_KUMA_/
    end
    assert_equal "", Setting.send(:"plugin_#{PLUGIN_ID}")["base_url"]
  end

  test "plain http to an outside host is refused at save until the setting is ticked" do
    log_user("admin", "admin")
    plain = GOOD_SETTINGS.merge("base_url" => "http://uptime.example.com")

    post SETTINGS_PATH, params: { settings: plain }
    assert_response :unprocessable_entity

    post SETTINGS_PATH, params: { settings: plain.merge("allow_plain_http" => "1") }
    assert_redirected_to SETTINGS_PATH
  end

  test "someone who is not an administrator cannot open or save the settings" do
    log_user("jsmith", "jsmith")

    get SETTINGS_PATH
    assert_response :forbidden
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS }
    assert_response :forbidden
    assert_equal "", Setting.send(:"plugin_#{PLUGIN_ID}")["base_url"]
  end

  test "settings of other plugins are not checked by this plugin" do
    patch_applied = SettingsController.include?(RubylodeUptimeKuma::SettingsControllerPatch)

    assert patch_applied
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_uptime_kuma"
    assert_response :success
  end

  test "the plugin shows its project address and author on the Plugins page" do
    plugin = Redmine::Plugin.find(:redmine_rubylode_uptime_kuma)
    readme = File.read(File.expand_path("../../README.md", __dir__))
    repository_name = readme[%r{git clone https://github\.com/rubylode/([\w-]+)\.git}, 1]
    assert_equal "redmine-rubylode-uptime-kuma", repository_name
    assert_equal "https://github.com/rubylode/#{repository_name}", plugin.url
    assert_equal "Rubylode", plugin.author
    assert_equal "https://github.com/rubylode", plugin.author_url
  end
end

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

# Acceptance behaviour 10: the token is never stored, rendered, logged or put in an error message.
class RubylodeUptimeKuma::TokenSecrecyTest < Redmine::IntegrationTest
  include RubylodeUptimeKumaTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issue_statuses, :trackers, :projects_trackers, :enumerations, :enabled_modules

  SAMPLE_TOKEN = "sample-token-DO-NOT-LEAK-7f3a91".freeze
  TOKEN_VARIABLE = "UPTIME_KUMA_SECRECY_TEST_TOKEN".freeze

  setup do
    use_memory_cache
    @server = FakeKumaServer.new(token: SAMPLE_TOKEN).start
    ENV[TOKEN_VARIABLE] = SAMPLE_TOKEN
    configure_plugin("base_url" => @server.base_url, "token_environment_variable" => TOKEN_VARIABLE, "cache_seconds" => "60")
    @log_path = Rails.root.join("log", "#{Rails.env}.log")
    @log_offset = File.exist?(@log_path) ? File.size(@log_path) : 0
  end

  teardown do
    ENV.delete(TOKEN_VARIABLE)
    @server.stop
    restore_cache
  end

  def log_written_during_test
    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    return "" unless File.exist?(@log_path)

    File.open(@log_path) { |file| file.seek(@log_offset); file.read.to_s }
  end

  test "with the right token the page works and the token is nowhere in the html or the log" do
    log_user("admin", "admin")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-summary", text: "All services up"
    refute_includes response.body, SAMPLE_TOKEN
    refute_includes log_written_during_test, SAMPLE_TOKEN
  end

  test "with a wrong token the page says unavailable and neither the html, the log nor the reason shows either token" do
    ENV[TOKEN_VARIABLE] = "wrong-token-also-secret-55"

    log_user("admin", "admin")
    get "/status/uptime_kuma"

    assert_select ".rubylode-service-status-summary", text: "Status unavailable"
    [SAMPLE_TOKEN, "wrong-token-also-secret-55"].each do |token|
      refute_includes response.body, token
      refute_includes log_written_during_test, token
    end
  end

  test "an error carrying the token in its own message is scrubbed before it reaches the page" do
    client = RubylodeUptimeKuma::KumaMetrics.new(url: "https://k.example.com/metrics", token: SAMPLE_TOKEN,
                                                 http_client: ->(*) { raise RubylodeUptimeKuma::KumaMetrics::Unavailable, "boom #{SAMPLE_TOKEN}" })

    error = assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { client.call }
    refute_includes error.message, SAMPLE_TOKEN
  end

  test "the settings page and the saved settings never hold the token" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_uptime_kuma"
    refute_includes response.body, SAMPLE_TOKEN
    assert_select "strong", text: "set in the environment"

    post "/settings/plugin/redmine_rubylode_uptime_kuma", params: { settings: Setting.send(:"plugin_#{PLUGIN_ID}") }
    refute_includes Setting.send(:"plugin_#{PLUGIN_ID}").to_s, SAMPLE_TOKEN
    assert_not_includes Setting.where("value LIKE ?", "%#{SAMPLE_TOKEN}%").to_a.map(&:name), "plugin_#{PLUGIN_ID}"
  end

  test "Kuma is asked once for two page loads within the cache window" do
    log_user("jsmith", "jsmith")
    2.times { get "/status/uptime_kuma" }

    assert_equal 1, @server.request_count
  end
end

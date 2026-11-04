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

class RubylodeUptimeKuma::KumaMetricsTest < ActiveSupport::TestCase
  SAMPLE_TOKEN = "secret-token-123".freeze

  def metrics(token: SAMPLE_TOKEN, http_client:)
    RubylodeUptimeKuma::KumaMetrics.new(url: "https://kuma.example.com/metrics", token: token, http_client: http_client)
  end

  test "a missing token is unavailable without calling Kuma" do
    called = false

    assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { metrics(token: "", http_client: ->(*) { called = true }).call }
    refute called
  end

  test "a missing token message names the variable, not a value" do
    client = RubylodeUptimeKuma::KumaMetrics.new(url: "https://k.example.com/metrics", token: "", token_environment_variable: "MY_KUMA_TOKEN")

    error = assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { client.call }
    assert_includes error.message, "MY_KUMA_TOKEN"
  end

  test "a rejected token is unavailable and the error never contains the token" do
    error = assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { metrics(http_client: ->(*) { [401, "Unauthorized"] }).call }

    refute_includes error.message, SAMPLE_TOKEN
  end

  test "a network failure is unavailable and the error never contains the token" do
    client = ->(*) { raise Timeout::Error, "with #{SAMPLE_TOKEN} inside" }

    error = assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { metrics(http_client: client).call }
    refute_includes error.message, SAMPLE_TOKEN
  end

  test "an accepted token returns the metrics text" do
    assert_equal "monitor_status 1", metrics(http_client: ->(*) { [200, "monitor_status 1"] }).call
  end
end

class RubylodeUptimeKuma::KumaMetricsOverHttpTest < ActiveSupport::TestCase
  include RubylodeUptimeKumaTestHelpers

  TOKEN = "fake-server-token-456".freeze

  setup do
    @server = FakeKumaServer.new(token: TOKEN).start
  end

  teardown do
    @server.stop
  end

  def metrics(token: TOKEN, timeout_seconds: 2)
    RubylodeUptimeKuma::KumaMetrics.new(url: @server.metrics_url, token: token, timeout_seconds: timeout_seconds)
  end

  test "the token is sent as the basic-auth password and the metrics come back" do
    text = metrics.call

    assert_includes text, %(monitor_status{monitor_name="Website homepage")
  end

  test "a wrong token is rejected by the server and reported as unavailable" do
    error = assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { metrics(token: "wrong").call }

    assert_match(/401/, error.message)
  end

  test "a broken Kuma is unavailable" do
    @server.scenario = "unavailable"

    assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { metrics.call }
  end

  test "nothing listening is unavailable" do
    port = @server.port
    @server.stop

    client = RubylodeUptimeKuma::KumaMetrics.new(url: "http://127.0.0.1:#{port}/metrics", token: TOKEN, timeout_seconds: 1)
    assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { client.call }
  end

  test "the token is not sent to a host that is not in the allowed hosts" do
    other = FakeKumaServer.new(token: TOKEN).start
    client = RubylodeUptimeKuma::KumaMetrics.new(url: "http://localhost:#{other.port}/metrics", token: TOKEN, allowed_hosts: ["127.0.0.1"])

    error = assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { client.call }
    assert_match(/not an allowed host/, error.message)
    assert_equal 0, other.request_count
    assert_empty other.authorization_headers
  ensure
    other&.stop
  end

  test "by default the token goes only to the host of the metrics url" do
    assert_includes metrics.call, "monitor_status"
    assert_equal 1, @server.authorization_headers.compact.size
  end

  test "a redirect to another host is not followed and the other host never sees the token" do
    other = FakeKumaServer.new(token: TOKEN).start
    @server.redirect_target = "http://localhost:#{other.port}/metrics"

    error = assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { metrics.call }

    assert_match(/redirect/i, error.message)
    assert_equal 0, other.request_count
    assert_empty other.authorization_headers
  ensure
    other&.stop
  end

  test "a redirect to a listed host is still not followed" do
    other = FakeKumaServer.new(token: TOKEN).start
    @server.redirect_target = "http://127.0.0.1:#{other.port}/metrics"

    assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { metrics.call }
    assert_equal 0, other.request_count
  ensure
    other&.stop
  end

  test "plain http to a host that is not this machine is refused unless allowed, and nothing is sent" do
    sent = false
    client = ->(*) { sent = true; [200, "x"] }
    refused = RubylodeUptimeKuma::KumaMetrics.new(url: "http://kuma.internal.example.com/metrics", token: TOKEN, http_client: client)
    allowed = RubylodeUptimeKuma::KumaMetrics.new(url: "http://kuma.internal.example.com/metrics", token: TOKEN, allow_plain_http: true, http_client: client)

    assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { refused.call }
    refute sent
    assert_equal "x", allowed.call
  end

  test "from_settings passes the allowed hosts, so a listed other host blocks the metrics url host" do
    settings = RubylodeUptimeKuma::Settings.new("base_url" => @server.base_url, "allowed_hosts" => "kuma.example.com")
    ENV["UPTIME_KUMA_API_TOKEN"] = TOKEN

    assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { RubylodeUptimeKuma::KumaMetrics.from_settings(settings).call }
    assert_equal 0, @server.request_count
  ensure
    ENV.delete("UPTIME_KUMA_API_TOKEN")
  end

  test "a variable outside the UPTIME_KUMA_ family is never read: the request is not made" do
    original = ENV["SECRET_KEY_BASE"]
    ENV["SECRET_KEY_BASE"] = TOKEN
    settings = RubylodeUptimeKuma::Settings.new("base_url" => @server.base_url, "token_environment_variable" => "SECRET_KEY_BASE")

    assert_raises(RubylodeUptimeKuma::KumaMetrics::Unavailable) { RubylodeUptimeKuma::KumaMetrics.from_settings(settings).call }
    assert_equal 0, @server.request_count
    assert_empty @server.authorization_headers
  ensure
    original ? ENV["SECRET_KEY_BASE"] = original : ENV.delete("SECRET_KEY_BASE")
  end

  test "from_settings reads the token from the environment variable named in the settings" do
    settings = RubylodeUptimeKuma::Settings.new("base_url" => @server.base_url, "token_environment_variable" => "UPTIME_KUMA_TEST_TOKEN")
    ENV["UPTIME_KUMA_TEST_TOKEN"] = TOKEN

    assert_includes RubylodeUptimeKuma::KumaMetrics.from_settings(settings).call, "monitor_status"
  ensure
    ENV.delete("UPTIME_KUMA_TEST_TOKEN")
  end
end

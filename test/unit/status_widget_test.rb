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

class RubylodeUptimeKuma::StatusWidgetTest < ActiveSupport::TestCase
  include RubylodeUptimeKumaTestHelpers

  setup do
    use_memory_cache
    configure_plugin
  end

  teardown do
    restore_cache
  end

  def widget_data
    RubylodeUptimeKuma::StatusWidget.data
  end

  test "all services up is ok, with a one-line summary and the response time as the detail" do
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 1, "Wiki" => 1 }, "Website homepage" => 142))

    data = widget_data

    assert_equal "ok", data[:state]
    assert_equal "3 of 3 services up", data[:summary]
    assert_equal({ name: "Website", state: "ok", detail: "142 ms" }, data[:items].first)
    assert_equal %w[Website Billing Wiki], data[:items].map { |item| item[:name] }
    assert_nil data[:items][1][:detail]
  end

  test "some services down is a warning, with the down ones first" do
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0, "Wiki" => 1 }))

    data = widget_data

    assert_equal "warning", data[:state]
    assert_equal "2 of 3 services up", data[:summary]
    assert_equal({ name: "Billing", state: "down", detail: nil }, data[:items].first)
    assert_equal %w[ok ok], data[:items].drop(1).map { |item| item[:state] }
  end

  test "every known service down is down" do
    publish_metrics(metrics_text({ "Website homepage" => 0, "Billing app health" => 0, "Wiki" => 0 }))

    assert_equal "down", widget_data[:state]
    assert_equal "0 of 3 services up", widget_data[:summary]
  end

  test "a service Kuma does not know is unknown and is counted apart" do
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 1 }))

    data = widget_data

    assert_equal "ok", data[:state]
    assert_equal "2 of 2 services up, 1 unknown", data[:summary]
    assert_equal "unknown", data[:items].find { |item| item[:name] == "Wiki" }[:state]
  end

  test "a single service is worded in the singular" do
    configure_plugin("services" => "Website | https://www.example.com | The public site | Website homepage")
    publish_metrics(metrics_text({ "Website homepage" => 1 }))

    assert_equal "1 of 1 service up", widget_data[:summary]
  end

  test "when no service is known the state is unknown" do
    publish_metrics(metrics_text({ "Something else" => 1 }))

    data = widget_data

    assert_equal "unknown", data[:state]
    assert_equal "Uptime Kuma does not know these services", data[:summary]
  end

  test "the response time is left out when the setting hides it" do
    configure_plugin("show_response_time" => "0")
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 1, "Wiki" => 1 }, "Website homepage" => 142))

    assert_nil widget_data[:items].first[:detail]
  end

  test "when Kuma cannot be asked the state is unknown and there are no items" do
    RubylodeUptimeKuma::ServiceStatus.cache.write(
      RubylodeUptimeKuma::ServiceStatus.cache_key_for("https://kuma.example.com/metrics"), "kuma-unavailable|Kuma answered 503"
    )

    data = widget_data

    assert_equal "unknown", data[:state]
    assert_equal "Status unavailable", data[:summary]
    assert_empty data[:items]
  end

  test "before the plugin is set up the state is unknown" do
    configure_plugin("base_url" => "")

    data = widget_data

    assert_equal "unknown", data[:state]
    assert_equal "Not set up yet", data[:summary]
    assert_empty data[:items]
  end

  test "the data carries the report for the partial and uses only the contract's four states" do
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0, "Wiki" => 1 }))

    data = widget_data

    assert_kind_of RubylodeUptimeKuma::ServiceStatus::Report, data[:report]
    assert_empty (data[:items].map { |item| item[:state] } + [data[:state]]) - %w[ok warning down unknown]
  end

  test "on the Status page the partial draws only the table, from the report the data carries" do
    publish_metrics(metrics_text({ "Website homepage" => 1, "Billing app health" => 0, "Wiki" => 1 }))
    User.current = User.find(2)
    status = Struct.new(:data).new(widget_data)
    RubylodeUptimeKuma::ServiceStatus.cache.clear

    html = ApplicationController.render(partial: "rubylode_uptime_kuma/status", locals: { widget: Object.new, status: status })
    page = Nokogiri::HTML.fragment(html)

    assert_equal 3, page.css("tbody tr").size
    assert_empty page.css("h3")
    assert_empty page.css(".rubylode-service-status-summary")
  ensure
    User.current = nil
  end

  # Registration with Rubylode Status
  test "it registers with the Status plugin when its registry exists" do
    configure_plugin("block_title" => "Our services", "visibility" => "admins")

    with_status_plugin_registry do
      RubylodeUptimeKuma::StatusWidget.register

      registration = FakeStatusRegistry.registrations.sole
      assert_equal "uptime_kuma", registration[:key]
      assert_equal "Our services", registration[:title].call
      assert_equal "/status/uptime_kuma", registration[:path]
      assert_equal "rubylode_uptime_kuma/status", registration[:partial]
      assert_equal "admins", registration[:visibility].call
      assert_kind_of Hash, registration[:data].call
    end
  end

  test "it registers nothing, and raises nothing, when the Status plugin is not installed" do
    refute defined?(RubylodeStatus::Registry)

    assert_nil RubylodeUptimeKuma::StatusWidget.register
  end
end

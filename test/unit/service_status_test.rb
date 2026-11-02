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

class RubylodeUptimeKuma::ServiceStatusTest < ActiveSupport::TestCase
  include RubylodeUptimeKumaTestHelpers

  CURATED = [
    RubylodeUptimeKuma::ServiceStatus::Service.new("Website", "https://www.example.com/", "Public site", "Website homepage"),
    RubylodeUptimeKuma::ServiceStatus::Service.new("Billing", "https://billing.example.com/", "Invoices", "Billing app"),
    RubylodeUptimeKuma::ServiceStatus::Service.new("Wiki", "https://wiki.example.com/", "Notes", "Wiki")
  ].freeze

  def report_for(statuses, response_times = {})
    text = metrics_text(statuses, response_times)
    RubylodeUptimeKuma::ServiceStatus.new(services: CURATED, fetch_metrics: -> { text }, cache: ActiveSupport::Cache::MemoryStore.new).report
  end

  test "every curated monitor up shows each service up and the all-up summary" do
    report = report_for("Website homepage" => 1, "Billing app" => 1, "Wiki" => 1)

    assert_equal %w[Website Billing Wiki], report.services.map(&:name)
    assert_equal [:up], report.services.map(&:state).uniq
    assert_equal "All services up", report.summary
  end

  test "down services come first and the summary counts them" do
    report = report_for("Website homepage" => 1, "Billing app" => 0, "Wiki" => 1)

    assert_equal %w[Billing Website Wiki], report.services.map(&:name)
    assert_equal :down, report.services.first.state
    assert_equal "1 of 3 down", report.summary
  end

  test "monitors that are not on the curated list do not appear" do
    report = report_for("Website homepage" => 1, "Billing app" => 1, "Wiki" => 1, "Vendor login (external)" => 0)

    assert_equal 3, report.services.size
    assert_equal "All services up", report.summary
  end

  test "a curated service with no monitor shows unknown and is left out of the count" do
    report = report_for("Website homepage" => 1, "Billing app" => 0)

    assert_equal :unknown, report.services.find { |service| service.name == "Wiki" }.state
    assert_equal "1 of 2 down", report.summary
  end

  test "each service carries the address of the service itself and its description" do
    report = report_for("Website homepage" => 1, "Billing app" => 1, "Wiki" => 1)
    billing = report.services.find { |service| service.name == "Billing" }

    assert_equal "https://billing.example.com/", billing.url
    assert_equal "Invoices", billing.description
  end

  test "the response time in milliseconds comes from Kuma, and is empty when Kuma has none" do
    report = report_for({ "Website homepage" => 1, "Billing app" => 0 },
                        "Website homepage" => 142, "Billing app" => -1)

    assert_equal 142, report.services.find { |service| service.name == "Website" }.response_time_milliseconds
    assert_nil report.services.find { |service| service.name == "Billing" }.response_time_milliseconds
    assert_nil report.services.find { |service| service.name == "Wiki" }.response_time_milliseconds
  end

  test "a monitor name that contains regular expression characters is matched literally" do
    service = RubylodeUptimeKuma::ServiceStatus::Service.new("Web", "https://w.example.com/", "", "Web (www.example.com) [prod]")
    text = metrics_text("Web (www.example.com) [prod]" => 1)
    report = RubylodeUptimeKuma::ServiceStatus.new(services: [service], fetch_metrics: -> { text }, cache: ActiveSupport::Cache::MemoryStore.new).report

    assert_equal :up, report.services.first.state
  end
end

class RubylodeUptimeKuma::ServiceStatusResilienceTest < ActiveSupport::TestCase
  include RubylodeUptimeKumaTestHelpers

  SERVICES = [RubylodeUptimeKuma::ServiceStatus::Service.new("Billing", "https://billing.example.com/", "Invoices", "Billing app")].freeze
  METRICS = %(monitor_status{monitor_name="Billing app",monitor_type="http"} 1)

  def status_with(cache: ActiveSupport::Cache::MemoryStore.new, **options, &fetch_metrics)
    RubylodeUptimeKuma::ServiceStatus.new(services: SERVICES, fetch_metrics: fetch_metrics, cache: cache, **options)
  end

  test "when Kuma cannot be reached the report says status unavailable" do
    report = status_with { raise RubylodeUptimeKuma::KumaMetrics::Unavailable, "Kuma did not answer" }.report

    assert report.unavailable?
    assert_equal "Status unavailable", report.summary
    assert_equal "Kuma did not answer", report.failure_reason
    assert_empty report.services
  end

  test "two requests within a minute ask Kuma once" do
    calls = 0
    status = status_with { calls += 1; METRICS }

    status.report
    status.report

    assert_equal 1, calls
  end

  test "a request after a minute asks Kuma again" do
    calls = 0
    status = status_with { calls += 1; METRICS }

    status.report
    travel 61.seconds
    status.report

    assert_equal 2, calls
  end

  test "a failed answer is remembered for half a minute so a down Kuma is not asked on every page" do
    calls = 0
    status = status_with { calls += 1; raise RubylodeUptimeKuma::KumaMetrics::Unavailable, "down" }

    2.times { assert status.report.unavailable? }
    assert_equal 1, calls

    travel 31.seconds
    assert status.report.unavailable?
    assert_equal 2, calls
  end

  test "the cache window and the failure window come from the settings" do
    calls = 0
    status = status_with(cache_seconds: 10, failure_seconds: 5) { calls += 1; METRICS }

    status.report
    travel 11.seconds
    status.report

    assert_equal 2, calls
  end

  test "a cache of zero seconds asks Kuma every time" do
    calls = 0
    status = status_with(cache_seconds: 0) { calls += 1; METRICS }

    2.times { status.report }

    assert_equal 2, calls
  end

  test "a different metrics url does not read another url's cached answer" do
    refute_equal RubylodeUptimeKuma::ServiceStatus.cache_key_for("https://a.example.com/metrics"),
                 RubylodeUptimeKuma::ServiceStatus.cache_key_for("https://b.example.com/metrics")
  end

  test "a cache that cannot be read or written still gives the report from a live fetch, and logs a warning" do
    calls = 0
    status = status_with(cache: RubylodeUptimeKumaTestHelpers::UnwritableCache.new) { calls += 1; METRICS }

    report = nil
    log = captured_log { report = status.report }

    refute report.unavailable?
    assert_equal :up, report.services.first.state
    assert_equal 1, calls
    assert_includes log, "WARN"
    assert_includes log, "Errno::EACCES"
  end

  test "a cache that cannot be written still gives the report from a live fetch" do
    status = status_with(cache: RubylodeUptimeKumaTestHelpers::UnwritableCache.new(read: false)) { METRICS }

    report = nil
    log = captured_log { report = status.report }

    refute report.unavailable?
    assert_equal :up, report.services.first.state
    assert_includes log, "cache write failed"
  end

  test "a failed fetch with a cache that cannot be written is the status unavailable report" do
    status = status_with(cache: RubylodeUptimeKumaTestHelpers::UnwritableCache.new) { raise RubylodeUptimeKuma::KumaMetrics::Unavailable, "Kuma did not answer" }

    report = nil
    captured_log { report = status.report }

    assert report.unavailable?
    assert_equal "Kuma did not answer", report.failure_reason
  end

  test "any error from the cache store is ignored, not only system call errors" do
    cache = Object.new
    def cache.read(*) = raise(TypeError, "incompatible marshal file format")
    def cache.write(*) = raise(IOError, "closed stream")

    report = nil
    captured_log { report = status_with(cache: cache) { METRICS }.report }

    refute report.unavailable?
  end

  test "safe_report answers status unavailable and logs the class when building the report raises" do
    configuration = RubylodeUptimeKuma::Configuration.current
    report = nil
    log = captured_log do
      replacing_method(RubylodeUptimeKuma::ServiceStatus, :current, ->(*) { raise ArgumentError, "boom" }) do
        report = RubylodeUptimeKuma::ServiceStatus.safe_report(configuration)
      end
    end

    assert report.unavailable?
    assert_equal "Status unavailable", report.summary
    assert_equal "ArgumentError", report.failure_reason
    assert_includes log, "ArgumentError: boom"
  end
end

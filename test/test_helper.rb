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

require File.expand_path("../../../test/test_helper", __dir__)
require_relative "support/fake_kuma_server"

module RubylodeUptimeKumaTestHelpers
  PLUGIN_ID = RedmineRubylodeUptimeKuma::PLUGIN_ID

  SAMPLE_SERVICES = <<~TEXT.freeze
    Website | https://www.example.com | The public site | Website homepage
    Billing | https://billing.example.com | Invoices | Billing app health
    Wiki | https://wiki.example.com | Internal notes | Wiki
  TEXT

  def metrics_text(statuses, response_times = {})
    lines = statuses.map { |monitor_name, value| %(monitor_status{monitor_name="#{monitor_name}",monitor_type="http",monitor_url="https://x/",monitor_hostname="null",monitor_port="null"} #{value}) }
    lines += response_times.map { |monitor_name, value| %(monitor_response_time{monitor_name="#{monitor_name}",monitor_type="http"} #{value}) }
    lines.join("\n")
  end

  def configure_plugin(overrides = {})
    settings = RedmineRubylodeUptimeKuma::Defaults::SETTINGS.merge(
      "metrics_url" => "https://kuma.example.com/metrics",
      "services" => SAMPLE_SERVICES,
      "dashboard_url" => "https://kuma.example.com/dashboard"
    ).merge(overrides.transform_keys(&:to_s))
    Setting.send(:"plugin_#{PLUGIN_ID}=", settings)
  end

  def use_memory_cache
    @original_cache = RubylodeUptimeKuma::ServiceStatus.cache
    RubylodeUptimeKuma::ServiceStatus.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def restore_cache
    RubylodeUptimeKuma::ServiceStatus.cache = @original_cache
  end

  # Puts Kuma's answer where the block looks for it, as if Kuma had just been asked.
  def publish_metrics(text, metrics_url: "https://kuma.example.com/metrics")
    RubylodeUptimeKuma::ServiceStatus.cache.write(RubylodeUptimeKuma::ServiceStatus.cache_key_for(metrics_url), text)
  end
end

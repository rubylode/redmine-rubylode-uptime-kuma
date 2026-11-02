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

module RubylodeUptimeKuma
  # The curated services joined with what Kuma reports: down first, unknown when Kuma has no such monitor,
  # a summary line, and a "status unavailable" report when Kuma cannot be asked. Kuma's answer is cached.
  class ServiceStatus
    Service = Struct.new(:name, :url, :description, :monitor_name)
    ServiceState = Struct.new(:name, :url, :description, :state, :response_time_milliseconds)
    Report = Struct.new(:services, :summary, :unavailable, :failure_reason) do
      alias_method :unavailable?, :unavailable

      def any_down?
        services.any? { |service| service.state == :down }
      end

      def summary_state
        return :unavailable if unavailable?

        any_down? ? :has_down : :all_up
      end
    end

    FAILURE_MARKER = "kuma-unavailable".freeze

    class << self
      attr_writer :cache

      def cache
        @cache ||= Rails.cache
      end

      def cache_key_for(metrics_url)
        "rubylode_uptime_kuma/metrics/#{Digest::SHA256.hexdigest(metrics_url.to_s)[0, 16]}"
      end

      def current(configuration = Configuration.current)
        new(services: configuration.services,
            fetch_metrics: -> { KumaMetrics.from_configuration(configuration).call },
            cache: cache,
            cache_key: cache_key_for(configuration.metrics_url),
            cache_seconds: configuration.cache_seconds,
            failure_seconds: configuration.failure_cache_seconds)
      end
    end

    def initialize(services:, fetch_metrics:, cache:, cache_key: self.class.cache_key_for(""), cache_seconds: 60, failure_seconds: 30)
      @services = services
      @fetch_metrics = fetch_metrics
      @cache = cache
      @cache_key = cache_key
      @cache_seconds = cache_seconds
      @failure_seconds = failure_seconds
    end

    def report
      metrics_text = cached_metrics
      states = monitor_states(metrics_text)
      response_times = monitor_response_times(metrics_text)
      service_states = @services.map do |service|
        ServiceState.new(service.name, service.url, service.description,
                         states.fetch(service.monitor_name, :unknown), response_times[service.monitor_name])
      end
      ordered = service_states.sort_by.with_index { |service, index| [service.state == :down ? 0 : 1, index] }
      Report.new(ordered, summary_for(ordered), false, nil)
    rescue KumaMetrics::Unavailable => error
      Report.new([], I18n.t("rubylode_uptime_kuma.status.unavailable"), true, error.message)
    end

    private

    def cached_metrics
      metrics = @cache.read(@cache_key)
      if metrics.nil?
        begin
          metrics = @fetch_metrics.call
          @cache.write(@cache_key, metrics, expires_in: @cache_seconds) if @cache_seconds.positive?
        rescue KumaMetrics::Unavailable => error
          metrics = "#{FAILURE_MARKER}|#{error.message}"
          @cache.write(@cache_key, metrics, expires_in: @failure_seconds) if @failure_seconds.positive?
        end
      end
      raise KumaMetrics::Unavailable, failure_reason_from(metrics) if metrics.start_with?(FAILURE_MARKER)

      metrics
    end

    def failure_reason_from(marker)
      reason = marker.split("|", 2)[1].to_s
      reason.empty? ? I18n.t("rubylode_uptime_kuma.errors.kuma_did_not_answer") : reason
    end

    def monitor_states(metrics_text)
      metric_values(metrics_text, "monitor_status").transform_values { |value| value.zero? ? :down : :up }
    end

    # Kuma reports -1 when a monitor has no response time (for example while it is down).
    def monitor_response_times(metrics_text)
      metric_values(metrics_text, "monitor_response_time").transform_values(&:round).select { |_, milliseconds| milliseconds >= 0 }
    end

    def metric_values(metrics_text, metric_name)
      pattern = /\A#{metric_name}\{.*monitor_name="(?<monitor_name>[^"]*)".*\}\s+(?<value>-?[\d.]+)/
      metrics_text.each_line.each_with_object({}) do |line, values|
        match = pattern.match(line)
        values[match[:monitor_name]] = match[:value].to_f if match
      end
    end

    def summary_for(service_states)
      known = service_states.reject { |service| service.state == :unknown }
      down = known.count { |service| service.state == :down }
      return I18n.t("rubylode_uptime_kuma.status.all_up") if down.zero?

      I18n.t("rubylode_uptime_kuma.status.some_down", down: down, known: known.size)
    end
  end
end

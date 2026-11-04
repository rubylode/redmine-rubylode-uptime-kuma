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

module RubylodeUptimeKuma
  # What the Rubylode Status plugin shows for this plugin: a state, a one-line summary and one item per service,
  # built from the same cached report as the block. See the widget contract in the Status plugin's docs.
  module StatusWidget
    SHORT_NAME = "uptime_kuma".freeze
    PATH = "/status/uptime_kuma".freeze
    PARTIAL = "rubylode_uptime_kuma/status".freeze
    ITEM_STATES = { up: "ok", down: "down", unknown: "unknown" }.freeze

    class << self
      # Puts the block on the Status page. Does nothing when the Status plugin is not installed.
      def register
        return unless defined?(RubylodeStatus::Registry)

        RubylodeStatus::Registry.register(
          key: SHORT_NAME,
          title: -> { Settings.current.block_title },
          path: PATH,
          data: -> { data },
          partial: PARTIAL,
          visibility: -> { Settings.current.visibility }
        )
      end

      def data
        settings = Settings.current
        return { state: "unknown", summary: translate("not_set_up"), items: [] } unless settings.configured?

        report = ServiceStatus.safe_report(settings)
        return { state: "unknown", summary: report.summary, items: [], report: report } if report.unavailable?

        { state: state_for(report), summary: summary_for(report), items: items_for(report, settings), report: report }
      end

      private

      def state_for(report)
        known = report.services.reject { |service| service.state == :unknown }
        down = known.count { |service| service.state == :down }
        if known.empty? then "unknown"
        elsif down.zero? then "ok"
        elsif down == known.size then "down"
        else "warning"
        end
      end

      def summary_for(report)
        known = report.services.reject { |service| service.state == :unknown }
        unknown_count = report.services.size - known.size
        return translate("none_known") if known.empty?

        summary = translate("services_up", count: known.size, up: known.count { |service| service.state == :up })
        unknown_count.zero? ? summary : translate("with_unknown", summary: summary, unknown: unknown_count)
      end

      def items_for(report, settings)
        report.services.map do |service|
          milliseconds = service.response_time_milliseconds
          detail = settings.show_response_time? && milliseconds ? "#{milliseconds} ms" : nil
          { name: service.name, state: ITEM_STATES.fetch(service.state, "unknown"), detail: detail }
        end
      end

      def translate(key, **options)
        I18n.t("rubylode_uptime_kuma.widget.#{key}", **options)
      end
    end
  end
end

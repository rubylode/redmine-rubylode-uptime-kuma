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
  # Checks the settings form before it is saved. Returns a list of messages, empty when everything is fine.
  # Empty values are fine where the plugin has a default or the setting is optional.
  class SettingsValidator
    NUMBER_FIELDS = { "cache_seconds" => 0, "failure_cache_seconds" => 0, "timeout_seconds" => 1 }.freeze

    def self.errors_for(raw_settings)
      new(raw_settings).errors
    end

    def initialize(raw_settings)
      @settings = (raw_settings || {}).to_h.stringify_keys
    end

    def errors
      messages = []
      messages << t("base_url_invalid") unless blank_or_web_address?("base_url")
      messages << t("dashboard_url_invalid") unless blank_or_web_address?("dashboard_url")
      messages << t("environment_variable_invalid") unless environment_variable_valid?
      messages.concat(destination_errors)
      messages << t("block_title_blank") if @settings.key?("block_title") && @settings["block_title"].to_s.strip.empty?
      messages << t("visibility_invalid") unless visibility_valid?
      messages << t("column_invalid") unless columns_valid?
      messages.concat(path_errors)
      messages.concat(number_errors)
      messages.concat(service_errors)
      messages
    end

    private

    def t(key, **options)
      I18n.t("rubylode_uptime_kuma.errors.#{key}", **options)
    end

    def blank_or_web_address?(key)
      value = @settings[key].to_s.strip
      return true if value.empty?

      uri = URI.parse(value)
      %w[http https].include?(uri.scheme) && !uri.host.to_s.empty?
    rescue URI::InvalidURIError
      false
    end

    def environment_variable_valid?
      name = @settings["token_environment_variable"].to_s.strip
      name.empty? || name.match?(Settings::ENVIRONMENT_VARIABLE_PATTERN)
    end

    def destination_errors
      messages = []
      hosts = @settings["allowed_hosts"].to_s.downcase.split(/[\s,;]+/).reject(&:empty?)
      bad_hosts = hosts.reject { |host| host.match?(Settings::HOST_PATTERN) }
      messages << t("allowed_hosts_invalid", hosts: bad_hosts.join(", ")) if bad_hosts.any?
      uri = web_uri(@settings["base_url"].to_s.strip)
      return messages unless uri

      host = uri.host.to_s.downcase
      messages << t("host_not_in_allowed_hosts", host: host) if hosts.any? && !hosts.include?(host)
      plain_http_allowed = @settings["allow_plain_http"].to_s == "1" || KumaMetrics::LOOPBACK_HOSTS.include?(host)
      messages << t("plain_http_refused") if uri.scheme == "http" && !plain_http_allowed
      messages
    end

    def web_uri(value)
      return nil if value.empty?

      uri = URI.parse(value)
      %w[http https].include?(uri.scheme) && !uri.host.to_s.empty? ? uri : nil
    rescue URI::InvalidURIError
      nil
    end

    def columns_valid?
      %w[welcome_page_column project_overview_column].all? do |key|
        !@settings.key?(key) || Settings::COLUMNS.include?(@settings[key].to_s)
      end
    end

    def path_errors
      patterns = @settings["matching_page_paths"].to_s.lines.map(&:strip).each_with_index.reject { |line, _| line.empty? || line.start_with?("#") }
      errors = patterns.filter_map do |pattern, index|
        problem = PathMatcher.problem_with(pattern)
        t("path_line_prefix", line_number: index + 1, message: t("path_#{problem}", maximum: PathMatcher::MAXIMUM_LENGTH)) if problem
      end
      errors << t("path_too_many", maximum: PathMatcher::MAXIMUM_PATTERNS) if patterns.size > PathMatcher::MAXIMUM_PATTERNS
      errors
    end

    def visibility_valid?
      !@settings.key?("visibility") || Settings::VISIBILITIES.include?(@settings["visibility"].to_s)
    end

    def number_errors
      NUMBER_FIELDS.filter_map do |key, minimum|
        value = @settings[key].to_s.strip
        next if value.empty?

        valid = value.match?(/\A\d+\z/) && value.to_i >= minimum
        t("number_invalid", field: I18n.t("rubylode_uptime_kuma.settings.#{key}"), minimum: minimum) unless valid
      end
    end

    def service_errors
      ServiceLineParser.parse(@settings["services"]).errors.map do |line_error|
        t("line_prefix", line_number: line_error.line_number, message: line_error.message)
      end
    end
  end
end

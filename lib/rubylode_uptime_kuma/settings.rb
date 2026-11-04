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
  # The plugin's settings, read with their defaults and clamped to sensible values. The token is not one of them:
  # only the NAME of the environment variable that holds it is a setting.
  class Settings
    PLUGIN_ID = :redmine_rubylode_uptime_kuma

    VISIBILITIES = %w[logged_in admins].freeze
    # The token variable must live in this family, so the setting can never point the plugin at Redmine's own secrets
    # (SECRET_KEY_BASE, a database password, ...) and send them to the metrics address.
    ENVIRONMENT_VARIABLE_PATTERN = /\AUPTIME_KUMA_[A-Z0-9_]*\z/
    HOST_PATTERN = /\A[a-z0-9]([a-z0-9.\-]*[a-z0-9])?\z/

    # What a fresh install starts with. Everything here is a plugin setting except the token, which is only ever read
    # from the environment variable named by "token_environment_variable".
    DEFAULTS = {
      "base_url" => "",
      "token_environment_variable" => "UPTIME_KUMA_API_TOKEN",
      "allowed_hosts" => "",
      "allow_plain_http" => "0",
      "services" => "",
      "dashboard_url" => "",
      "cache_seconds" => "60",
      "failure_cache_seconds" => "30",
      "timeout_seconds" => "2",
      "show_response_time" => "1",
      "block_title" => "Services",
      "show_on_welcome_page" => "0",
      "welcome_page_column" => "right",
      "show_on_my_page" => "0",
      "show_on_project_overview" => "0",
      "project_overview_column" => "right",
      "show_on_matching_pages" => "0",
      "matching_page_paths" => "",
      "show_in_top_menu" => "0",
      "visibility" => "logged_in"
    }.freeze

    def self.current
      new(Setting.send(:"plugin_#{PLUGIN_ID}"))
    end

    def initialize(raw_settings = {})
      @settings = DEFAULTS.merge((raw_settings || {}).to_h.stringify_keys.compact)
    end

    # The address of Uptime Kuma, without /metrics.
    def base_url
      @settings["base_url"].to_s.strip
    end

    # Where the plugin asks: the address plus /metrics, unless the saved address already ends that way.
    def metrics_url
      return "" if base_url.empty?

      address = base_url.chomp("/")
      address.end_with?("/metrics") ? address : "#{address}/metrics"
    end

    # Nil when the configured name is not allowed: the token is then treated as missing and no variable is read.
    def token_environment_variable
      name = @settings["token_environment_variable"].to_s.strip
      name.match?(ENVIRONMENT_VARIABLE_PATTERN) ? name : nil
    end

    def token
      name = token_environment_variable
      name ? ENV[name].to_s : ""
    end

    # Hosts the token may be sent to. Empty means only the host of the metrics URL.
    def allowed_hosts
      @settings["allowed_hosts"].to_s.downcase.split(/[\s,;]+/).reject(&:empty?)
    end

    def allow_plain_http?
      @settings["allow_plain_http"].to_s == "1"
    end

    def services_text
      @settings["services"].to_s
    end

    def services
      ServiceLineParser.parse(services_text).services
    end

    def dashboard_url
      @settings["dashboard_url"].to_s.strip
    end

    def cache_seconds
      whole_number("cache_seconds", minimum: 0)
    end

    def failure_cache_seconds
      whole_number("failure_cache_seconds", minimum: 0)
    end

    def timeout_seconds
      whole_number("timeout_seconds", minimum: 1)
    end

    def show_response_time?
      @settings["show_response_time"].to_s == "1"
    end

    def block_title
      title = @settings["block_title"].to_s.strip
      title.empty? ? DEFAULTS["block_title"] : title
    end

    COLUMNS = %w[left right].freeze

    def show_on_welcome_page?
      flag?("show_on_welcome_page")
    end

    def welcome_page_column
      column("welcome_page_column")
    end

    def show_on_my_page?
      flag?("show_on_my_page")
    end

    def show_on_project_overview?
      flag?("show_on_project_overview")
    end

    def project_overview_column
      column("project_overview_column")
    end

    def show_on_matching_pages?
      flag?("show_on_matching_pages") && matching_page_paths.any?
    end

    def matching_page_paths
      PathMatcher.patterns_from(@settings["matching_page_paths"])
    end

    def show_in_top_menu?
      flag?("show_in_top_menu")
    end

    def visibility
      VISIBILITIES.include?(@settings["visibility"].to_s) ? @settings["visibility"].to_s : "logged_in"
    end

    def visible_to?(user)
      return false unless user&.logged?

      visibility == "admins" ? user.admin? : true
    end

    def configured?
      !metrics_url.empty? && services.any?
    end

    private

    def flag?(key)
      @settings[key].to_s == "1"
    end

    def column(key)
      COLUMNS.include?(@settings[key].to_s) ? @settings[key].to_s : "right"
    end

    def whole_number(key, minimum:)
      value = Integer(@settings[key].to_s.strip, 10)
      [value, minimum].max
    rescue ArgumentError
      Integer(DEFAULTS[key], 10)
    end
  end
end

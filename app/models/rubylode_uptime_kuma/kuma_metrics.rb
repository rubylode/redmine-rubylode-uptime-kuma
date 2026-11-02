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

require "net/http"

module RubylodeUptimeKuma
  # Asks Kuma's /metrics endpoint for its Prometheus text, with the API token as the basic-auth password.
  # The token is held only in memory for the request: it is not logged, and it is scrubbed from every error message.
  class KumaMetrics
    class Unavailable < StandardError; end

    LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1 [::1]].freeze

    def self.from_configuration(configuration)
      new(url: configuration.metrics_url,
          token: configuration.token,
          timeout_seconds: configuration.timeout_seconds,
          token_environment_variable: configuration.token_environment_variable,
          allowed_hosts: configuration.allowed_hosts,
          allow_plain_http: configuration.allow_plain_http?)
    end

    def initialize(url:, token:, timeout_seconds: 2, token_environment_variable: nil, allowed_hosts: [], allow_plain_http: false, http_client: nil)
      @url = url
      @token = token
      @timeout_seconds = timeout_seconds
      @token_environment_variable = token_environment_variable
      @allowed_hosts = allowed_hosts.map { |host| host.to_s.downcase }
      @allow_plain_http = allow_plain_http
      @http_client = http_client || method(:fetch_over_http)
    end

    def call
      raise Unavailable, token_missing_message if @token.empty?

      refuse_unsafe_destination!
      status, body = @http_client.call(@url, @token)
      raise Unavailable, I18n.t("rubylode_uptime_kuma.errors.kuma_redirect") if (300..399).cover?(status)
      raise Unavailable, I18n.t("rubylode_uptime_kuma.errors.kuma_status", status: status) unless status == 200

      body
    rescue Unavailable => error
      raise Unavailable, scrub(error.message)
    rescue StandardError => error
      raise Unavailable, I18n.t("rubylode_uptime_kuma.errors.kuma_unreachable", error_class: error.class)
    end

    private

    # The token goes only to a listed host, and over https unless the host is this machine or plain http was allowed.
    def refuse_unsafe_destination!
      uri = URI.parse(@url)
      host = uri.host.to_s.downcase
      permitted_hosts = @allowed_hosts.empty? ? [host] : @allowed_hosts
      raise Unavailable, I18n.t("rubylode_uptime_kuma.errors.host_not_allowed", host: host) unless !host.empty? && permitted_hosts.include?(host)

      secure = uri.scheme == "https" || (uri.scheme == "http" && (@allow_plain_http || LOOPBACK_HOSTS.include?(host)))
      raise Unavailable, I18n.t("rubylode_uptime_kuma.errors.plain_http_refused") unless secure
    rescue URI::InvalidURIError
      raise Unavailable, I18n.t("rubylode_uptime_kuma.errors.kuma_unreachable", error_class: "URI::InvalidURIError")
    end

    def token_missing_message
      base = I18n.t("rubylode_uptime_kuma.errors.token_missing")
      @token_environment_variable ? "#{base} (#{@token_environment_variable})" : base
    end

    def scrub(message)
      @token.empty? ? message : message.gsub(@token, "[filtered]")
    end

    def fetch_over_http(url, token)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request.basic_auth("", token)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                     open_timeout: @timeout_seconds, read_timeout: @timeout_seconds) do |http|
        http.request(request)
      end
      [response.code.to_i, response.body]
    end
  end
end

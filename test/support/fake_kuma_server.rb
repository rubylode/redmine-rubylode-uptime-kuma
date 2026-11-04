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

require "socket"
require "base64"

# A tiny stand-in for Uptime Kuma's /metrics endpoint, for the demo and the integration tests. Standard library only.
#
# GET /metrics answers Prometheus text like Kuma's, but only when the request carries HTTP basic auth with the token as the
# password (Kuma's own scheme); otherwise 401. What it reports depends on the scenario:
#
#   all_up       every monitor up
#   one_down     "Billing app health" down
#   mixed        "Billing app health" down and "Reports app" missing from the answer
#   unavailable  503, as if Kuma were broken
#
# POST /__scenario/<name> switches the scenario (no token needed); GET /__requests returns how many times /metrics was asked.
# Run it on its own:  FAKE_KUMA_TOKEN=some-token FAKE_KUMA_PORT=9100 ruby test/support/fake_kuma_server.rb
class FakeKumaServer
  # Monitor name => response time in milliseconds when up. "Vendor login (external)" is one the curated lists leave out.
  MONITORS = {
    "Website homepage" => 142,
    "Billing app health" => 88,
    "Wiki" => 215,
    "Support desk" => 64,
    "Reports app" => 301,
    "Vendor login (external)" => 450
  }.freeze

  SCENARIOS = %w[all_up one_down mixed unavailable].freeze

  # authorization_headers: what every /metrics request carried, so a test can prove a token never arrived.
  # redirect_target: when set, /metrics answers 302 to that address instead of serving metrics.
  attr_reader :port, :request_count, :authorization_headers
  attr_accessor :scenario, :redirect_target

  def initialize(token:, port: 0, scenario: "all_up", host: "127.0.0.1")
    @token = token
    @host = host
    @requested_port = port
    @scenario = scenario
    @request_count = 0
    @authorization_headers = []
  end

  def start
    @server = TCPServer.new(@host, @requested_port)
    @port = @server.addr[1]
    @thread = Thread.new { accept_loop }
    self
  end

  def stop
    @server&.close
    @thread&.join(2)
  end

  def base_url
    "http://#{@host}:#{@port}"
  end

  def metrics_url
    "#{base_url}/metrics"
  end

  def metrics_text
    return "" if scenario == "unavailable"

    MONITORS.filter_map do |name, milliseconds|
      next if scenario == "mixed" && name == "Reports app"

      up = !(scenario != "all_up" && name == "Billing app health")
      labels = %(monitor_name="#{name}",monitor_type="http",monitor_url="https://example.com/",monitor_hostname="null",monitor_port="null")
      "monitor_status{#{labels}} #{up ? 1 : 0}\nmonitor_response_time{#{labels}} #{up ? milliseconds : -1}"
    end.join("\n") + "\n"
  end

  private

  def accept_loop
    loop do
      client = @server.accept
      Thread.new(client) { |connection| handle(connection) }
    rescue IOError, Errno::EBADF
      break
    end
  end

  def handle(client)
    request_line = client.gets.to_s
    headers = {}
    while (line = client.gets) && line != "\r\n"
      name, value = line.split(":", 2)
      headers[name.downcase] = value.to_s.strip
    end
    method, path = request_line.split(" ")
    status, body = respond(method, path.to_s, headers)
    client.write("HTTP/1.1 #{status}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
  rescue StandardError
    nil
  ensure
    client.close
  end

  def respond(method, path, headers)
    if method == "POST" && path.start_with?("/__scenario/")
      name = path.delete_prefix("/__scenario/")
      return ["404 Not Found", "unknown scenario\n"] unless SCENARIOS.include?(name)

      self.scenario = name
      ["200 OK", "scenario #{name}\n"]
    elsif path == "/__requests"
      ["200 OK", "#{request_count}\n"]
    elsif path == "/metrics"
      @request_count += 1
      @authorization_headers << headers["authorization"]
      return ["302 Found\r\nLocation: #{redirect_target}", ""] if redirect_target
      return ["503 Service Unavailable", "kuma is unwell\n"] if scenario == "unavailable"

      token_accepted?(headers["authorization"]) ? ["200 OK", metrics_text] : ["401 Unauthorized", "bad token\n"]
    else
      ["404 Not Found", "not found\n"]
    end
  end

  def token_accepted?(authorization)
    return false unless authorization.to_s.start_with?("Basic ")

    _user, password = Base64.decode64(authorization.delete_prefix("Basic ")).split(":", 2)
    password == @token
  end
end

if $PROGRAM_NAME == __FILE__
  server = FakeKumaServer.new(token: ENV.fetch("FAKE_KUMA_TOKEN"), port: ENV.fetch("FAKE_KUMA_PORT", "9100").to_i,
                              host: "0.0.0.0", scenario: ENV.fetch("FAKE_KUMA_SCENARIO", "all_up")).start
  puts "Fake Kuma on port #{server.port}, scenario #{server.scenario}"
  $stdout.flush
  sleep
end

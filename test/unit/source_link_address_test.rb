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

class RubylodeUptimeKuma::SourceLinkAddressTest < ActiveSupport::TestCase
  def settings_from(raw_settings = {})
    RubylodeUptimeKuma::Settings.new(raw_settings)
  end

  test "the dashboard link is the address when it is set" do
    settings = settings_from("base_url" => "https://kuma.example.com", "dashboard_url" => "https://kuma.example.com/dashboard")

    assert_equal "https://kuma.example.com/dashboard", settings.source_link_address
  end

  test "an empty dashboard link falls back to the base address" do
    assert_equal "https://kuma.example.com", settings_from("base_url" => "https://kuma.example.com", "dashboard_url" => "").source_link_address
  end

  test "the base address is used as the person typed it, without /metrics added" do
    assert_equal "https://kuma.example.com", settings_from("base_url" => " https://kuma.example.com ").source_link_address
  end

  test "no address at all gives nil" do
    assert_nil settings_from({}).source_link_address
  end

  test "an address that is not a web address gives nil" do
    assert_nil settings_from("base_url" => "https://kuma.example.com", "dashboard_url" => "javascript:alert(1)").source_link_address
    assert_nil settings_from("base_url" => "ftp://kuma.example.com").source_link_address
    assert_nil settings_from("base_url" => "https://").source_link_address
  end
end

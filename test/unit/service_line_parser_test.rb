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

class RubylodeUptimeKuma::ServiceLineParserTest < ActiveSupport::TestCase
  def parse(text)
    RubylodeUptimeKuma::ServiceLineParser.parse(text)
  end

  test "a line becomes a service with name, address, description and monitor name" do
    result = parse("Website | https://www.example.com | The public site | Website homepage")

    assert result.valid?
    service = result.services.first
    assert_equal ["Website", "https://www.example.com", "The public site", "Website homepage"],
                 [service.name, service.url, service.description, service.monitor_name]
  end

  test "blank lines and comment lines are skipped and the order is kept" do
    result = parse("# the list\n\nA | https://a.example.com | one | A\n\n  \nB | https://b.example.com | two | B\n")

    assert_equal %w[A B], result.services.map(&:name)
    assert result.valid?
  end

  test "an empty description is allowed and an empty monitor name means the name" do
    service = parse("Wiki | https://wiki.example.com | |").services.first

    assert_equal "", service.description
    assert_equal "Wiki", service.monitor_name
  end

  test "a line with the wrong number of fields is an error with its line number" do
    result = parse("A | https://a.example.com | one | A\nB | https://b.example.com\n")

    assert_equal 1, result.services.size
    assert_equal [2], result.errors.map(&:line_number)
    assert_match(/4 fields/, result.errors.first.message)
  end

  test "a missing name and an address that is not http or https are errors" do
    result = parse(" | https://a.example.com | x | A\nB | ftp://b.example.com | x | B\nC | not a url | x | C")

    assert_empty result.services
    assert_equal [1, 2, 3], result.errors.map(&:line_number)
  end

  test "every bad line is reported and the good ones are still read" do
    result = parse("A | https://a.example.com | x | A\nbroken\nC | https://c.example.com | x | C")

    assert_equal %w[A C], result.services.map(&:name)
    assert_equal [2], result.errors.map(&:line_number)
    refute result.valid?
  end

  test "nil and empty text give an empty valid result" do
    assert parse(nil).valid?
    assert_empty parse("").services
  end
end

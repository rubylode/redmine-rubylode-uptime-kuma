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

# The plugin's own words follow the voice rules: en-US spelling, and no em or en dashes anywhere a person reads.
class RubylodeUptimeKuma::WordingTest < ActiveSupport::TestCase
  ROOT = File.expand_path("../..", __dir__)
  READABLE_FILES = Dir.glob(File.join(ROOT, "{app,config,lib,docs}/**/*.{rb,erb,yml,md}")) +
                   Dir.glob(File.join(ROOT, "*.{rb,md}")) - [File.expand_path(__FILE__)]

  test "no file a person reads has an em or en dash" do
    offenders = READABLE_FILES.select { |path| File.read(path).match?(/[–—]/) }

    assert_empty offenders.map { |path| path.delete_prefix("#{ROOT}/") }
  end

  test "the spelling is en-US" do
    british = /\b(colour\w*|licence\w*|visuali[s]ation\w*|behaviour\w*)\b/i
    offenders = READABLE_FILES.select { |path| File.read(path).match?(british) }

    assert_empty offenders.map { |path| path.delete_prefix("#{ROOT}/") }
  end

  test "no description or hint calls cached data live" do
    texts = READABLE_FILES.reject { |path| path.end_with?("CHANGELOG.md") }.map { |path| [path, File.read(path)] }
    offenders = texts.select { |_path, text| text.match?(/\blive (service )?status\b/i) }.map(&:first)

    assert_empty offenders.map { |path| path.delete_prefix("#{ROOT}/") }
  end

  test "the locale file has one root, and only the keys Redmine reads sit outside it" do
    locale = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en")

    assert_equal %w[my rubylode_uptime_kuma], locale.keys.sort
    assert_equal ["blocks"], locale["my"].keys
  end

  test "every setting has a label and, except the response time, a hint in the locale file" do
    locale = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).dig("en", "rubylode_uptime_kuma", "settings")
    keys = RubylodeUptimeKuma::Settings::DEFAULTS.keys

    keys.each do |key|
      assert locale.dig(key, "label").present?, "#{key} has no label"
      assert locale.dig(key, "hint").present?, "#{key} has no hint" unless key == "show_response_time" || key == "visibility"
    end
  end
end

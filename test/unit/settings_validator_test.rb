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

class RubylodeUptimeKuma::SettingsValidatorTest < ActiveSupport::TestCase
  GOOD = {
    "base_url" => "https://kuma.example.com",
    "token_environment_variable" => "UPTIME_KUMA_API_TOKEN",
    "services" => "Website | https://www.example.com | The site | Website homepage",
    "dashboard_url" => "https://kuma.example.com/dashboard",
    "cache_seconds" => "60", "failure_cache_seconds" => "30", "timeout_seconds" => "2",
    "show_response_time" => "1", "block_title" => "Services", "visibility" => "logged_in"
  }.freeze

  def errors_for(overrides = {})
    RubylodeUptimeKuma::SettingsValidator.errors_for(GOOD.merge(overrides))
  end

  test "good settings have no errors" do
    assert_empty errors_for
  end

  test "empty optional values are fine" do
    assert_empty errors_for("base_url" => "", "dashboard_url" => "", "services" => "", "cache_seconds" => "")
  end

  test "the metrics url and the dashboard link must be web addresses" do
    assert_equal 1, errors_for("base_url" => "kuma.example.com").size
    assert_equal 1, errors_for("dashboard_url" => "javascript:alert(1)").size
  end

  test "the token variable name must look like an environment variable name" do
    assert_empty errors_for("token_environment_variable" => "UPTIME_KUMA_TOKEN_2")
    assert_equal 1, errors_for("token_environment_variable" => "1 BAD NAME").size
    assert_equal 1, errors_for("token_environment_variable" => "secret-token-value").size
  end

  test "a variable that is not in the UPTIME_KUMA_ family is rejected, so no other secret can be named" do
    %w[SECRET_KEY_BASE DATABASE_PASSWORD HOME UPTIME_KUMA lower_case].each do |name|
      errors = errors_for("token_environment_variable" => name)

      assert_equal 1, errors.size, name
      assert_match(/UPTIME_KUMA_/, errors.first)
    end
  end

  test "plain http to a host that is not this machine needs the explicit setting" do
    assert_equal 1, errors_for("base_url" => "http://kuma.internal.example.com").size
    assert_empty errors_for("base_url" => "http://kuma.internal.example.com", "allow_plain_http" => "1")
    assert_empty errors_for("base_url" => "http://127.0.0.1:3001")
    assert_empty errors_for("base_url" => "http://localhost:3001")
  end

  test "when allowed hosts are listed the metrics url host must be one of them, and each must be a plain host name" do
    assert_empty errors_for("allowed_hosts" => "kuma.example.com")
    assert_equal 1, errors_for("allowed_hosts" => "other.example.com").size
    assert_equal 1, errors_for("allowed_hosts" => "kuma.example.com, https://evil.example.com/x").size
  end

  test "the numbers must be whole and in range" do
    assert_equal 1, errors_for("cache_seconds" => "-5").size
    assert_equal 1, errors_for("failure_cache_seconds" => "soon").size
    assert_equal 1, errors_for("timeout_seconds" => "0").size
    assert_empty errors_for("cache_seconds" => "0")
  end

  test "who may see the block must be one of the choices and the title cannot be empty" do
    assert_equal 1, errors_for("visibility" => "everybody").size
    assert_equal 1, errors_for("block_title" => "  ").size
  end

  test "the welcome page column must be left or right" do
    assert_empty errors_for("welcome_page_column" => "left")
    assert_equal 1, errors_for("welcome_page_column" => "centre").size
  end

test "path patterns must be paths, with the line number of a bad one" do
    assert_empty errors_for("matching_page_paths" => "/issues\n# note\n\n/projects/*/issues")
    errors = errors_for("matching_page_paths" => "/issues\nhttps://example.com/x\n//host/y\n/with space")
  
    assert_equal 3, errors.size
    assert_match(/line 2/, errors[0])
    assert_match(/line 3/, errors[1])
    assert_match(/line 4/, errors[2])
  end
  
  test "too many paths and over-long paths are refused" do
    assert_equal 1, errors_for("matching_page_paths" => (1..51).map { |number| "/page#{number}" }.join("\n")).size
    assert_equal 1, errors_for("matching_page_paths" => "/#{'a' * 250}").size
  end
  
  test "both columns must be left or right" do
    assert_equal 1, errors_for("project_overview_column" => "top").size
  end
  
  test "bad service lines are reported with their line numbers" do
    errors = errors_for("services" => "A | https://a.example.com | x | A\nbroken line\nC | nope | x | C")

    assert_equal 2, errors.size
    assert_match(/line 2/, errors[0])
    assert_match(/line 3/, errors[1])
  end
end

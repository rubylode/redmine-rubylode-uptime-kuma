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

module RedmineRubylodeUptimeKuma
  PLUGIN_ID = :redmine_rubylode_uptime_kuma

  # What a fresh install starts with. Everything here is a plugin setting except the token, which is only ever read from
  # the environment variable named by "token_environment_variable".
  module Defaults
    SETTINGS = {
      "metrics_url" => "",
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
  end
end

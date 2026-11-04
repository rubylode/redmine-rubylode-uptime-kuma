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
  # Puts the status block on the welcome (Home) page, the project Overview and the pages on the path list, as the settings
  # ask. The block is the same partial as everywhere else, so permission, caching and the fallback are the same too.
  class Hooks < Redmine::Hook::ViewListener
    def view_welcome_index_left(context)
      render_in_column(context, "left", :show_on_welcome_page?, :welcome_page_column)
    end

    def view_welcome_index_right(context)
      render_in_column(context, "right", :show_on_welcome_page?, :welcome_page_column)
    end

    def view_projects_show_left(context)
      render_in_column(context, "left", :show_on_project_overview?, :project_overview_column)
    end

    def view_projects_show_right(context)
      render_in_column(context, "right", :show_on_project_overview?, :project_overview_column)
    end

    # The block under the content is drawn after the head, so on a listed page the stylesheet is linked here.
    def view_layouts_base_html_head(context)
      return "" unless on_listed_page?(context)

      stylesheet_link_tag("rubylode_uptime_kuma", plugin: "redmine_rubylode_uptime_kuma")
    end

    # Under the content of every page whose path is on the list. Redmine has no hook above the content.
    def view_layouts_base_content(context)
      return "" unless on_listed_page?(context)

      context[:hook_caller].render(partial: "rubylode_uptime_kuma/status", locals: { compact: true })
    end

    private

    def on_listed_page?(context)
      settings = RubylodeUptimeKuma::Settings.current
      return false unless settings.show_on_matching_pages? && settings.visible_to?(User.current)

      RubylodeUptimeKuma::PathMatcher.new(settings.matching_page_paths).match?(context[:request].path)
    end

    def render_in_column(context, column, enabled_method, column_method)
      settings = RubylodeUptimeKuma::Settings.current
      return "" unless settings.public_send(enabled_method) && settings.public_send(column_method) == column

      context[:hook_caller].render(partial: "rubylode_uptime_kuma/status")
    end
  end
end

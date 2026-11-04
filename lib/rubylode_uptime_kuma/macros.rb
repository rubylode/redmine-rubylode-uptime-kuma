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
  module Macros
    def self.register
      # The same block as {{service_status}} under a second, self-describing name.
      Redmine::WikiFormatting::Macros.register do
        %i[service_status uptime_kuma_status].each do |macro_name|
          desc <<~DESCRIPTION
            Shows the live status of the services listed in the Rubylode Uptime Kuma settings.

              {{#{macro_name}}}
              {{#{macro_name}(title=Our services)}}

            Nothing is shown to people who are not allowed to see it.
          DESCRIPTION
          macro macro_name do |_object, arguments|
            _positional, options = extract_macro_options(arguments, :title)
            render partial: "rubylode_uptime_kuma/service_status", locals: { title: options[:title].presence }
          end
        end
      end
    end
  end
end

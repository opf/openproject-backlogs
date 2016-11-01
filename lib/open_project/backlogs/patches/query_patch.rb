#-- copyright
# OpenProject Backlogs Plugin
#
# Copyright (C)2013-2014 the OpenProject Foundation (OPF)
# Copyright (C)2011 Stephan Eckardt, Tim Felgentreff, Marnen Laibow-Koser, Sandro Munda
# Copyright (C)2010-2011 friflaj
# Copyright (C)2010 Maxime Guilbot, Andrew Vit, Joakim Kolsjö, ibussieres, Daniel Passos, Jason Vasquez, jpic, Emiliano Heyns
# Copyright (C)2009-2010 Mark Maglana
# Copyright (C)2009 Joe Heck, Nate Lowrie
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 3.
#
# OpenProject Backlogs is a derivative work based on ChiliProject Backlogs.
# The copyright follows:
# Copyright (C) 2010-2011 - Emiliano Heyns, Mark Maglana, friflaj
# Copyright (C) 2011 - Jens Ulferts, Gregor Schmidt - Finn GmbH - Berlin, Germany
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
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require_dependency 'query'

module OpenProject::Backlogs::Patches::QueryPatch
  def self.included(base)
    base.class_eval do
      include InstanceMethods

      add_available_column(QueryColumn.new(:story_points,
                                           sortable: "#{WorkPackage.table_name}.story_points",
                                           summable: true))
      add_available_column(QueryColumn.new(:remaining_hours,
                                           sortable: "#{WorkPackage.table_name}.remaining_hours",
                                           summable: true))

      Queries::WorkPackages::Filter.add_filter_type_by_field('backlogs_work_package_type', 'list')

      alias_method_chain :sql_for_field, :backlogs_work_package_type
    end
  end

  module InstanceMethods
    def sql_for_field_with_backlogs_work_package_type(field, operator, v, db_table, db_field, is_custom_filter = false)
      if field == 'backlogs_work_package_type'
        db_table = WorkPackage.table_name

        sql = []

        selected_values = values_for(field)
        selected_values = ['story', 'task'] if selected_values.include?('any')

        story_types = Story.types.map { |val| "#{val}" }.join(',')
        all_types = (Story.types + [Task.type]).map { |val| "#{val}" }.join(',')

        selected_values.each do |val|
          case val
          when 'story'
            sql << "(#{db_table}.type_id IN (#{story_types}))"
          when 'task'
            sql << "(#{db_table}.type_id = #{Task.type} AND NOT #{db_table}.parent_id IS NULL)"
          when 'impediment'
            sql << "(#{db_table}.id IN (
                  select from_id
                  FROM relations ir
                  JOIN work_packages blocked
                  ON
                    blocked.id = ir.to_id
                    AND blocked.type_id IN (#{all_types})
                  WHERE ir.relation_type = 'blocks'
                ) AND #{db_table}.parent_id IS NULL)"
          end
        end

        case operator
        when '='
          sql = sql.join(' OR ')
        when '!'
          sql = 'NOT (' + sql.join(' OR ') + ')'
        end

        sql
      else
        sql_for_field_without_backlogs_work_package_type(field, operator, v, db_table, db_field, is_custom_filter)
      end
    end

    protected
  end
end

Query.send(:include, OpenProject::Backlogs::Patches::QueryPatch)

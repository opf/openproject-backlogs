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

require 'spec_helper'

describe 'Empty backlogs project',
         type: :feature,
         js: true do
  let(:project) { FactoryGirl.create(:project, types: [story, task], enabled_module_names: %w(backlogs)) }
  let(:story) { FactoryGirl.create(:type_feature) }
  let(:task) { FactoryGirl.create(:type_task) }
  let(:status) { FactoryGirl.create(:status, is_default: true) }

  before do
    project
    status

    login_as current_user
    allow(Setting)
        .to receive(:plugin_openproject_backlogs)
                .and_return('story_types' => [story.id.to_s],
                            'task_type' => task.id.to_s)

    visit backlogs_project_backlogs_path(project)
  end

  context 'as admin' do
    let(:current_user) { FactoryGirl.create(:admin) }

    it 'should show a no results box with action' do
      expect(page).to have_selector '.generic-table--no-results-container', text: I18n.t(:backlogs_empty_title)
      expect(page).to have_selector '.generic-table--no-results-description', text: I18n.t(:backlogs_empty_action_text)

      link = page.find '.generic-table--no-results-description a'
      expect(link[:href]).to include(new_project_version_path(project))
    end
  end

  context 'as regular member' do
    let(:role) { FactoryGirl.create(:role, permissions: %i(view_master_backlog)) }
    let(:current_user) { FactoryGirl.create :user, member_in_project: project, member_through_role: role }

    it 'should only show a no results box' do
      expect(page).to have_selector '.generic-table--no-results-container', text: I18n.t(:backlogs_empty_title)
      expect(page).to have_no_selector '.generic-table--no-results-description'
    end
  end
end

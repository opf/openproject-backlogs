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

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Impediments::UpdateService, type: :model do
  let(:instance) { described_class.new(user: user, impediment: impediment) }

  let(:user) { FactoryGirl.create(:user) }
  let(:role) { FactoryGirl.create(:role, permissions: %i(edit_work_packages view_work_packages)) }
  let(:type_feature) { FactoryGirl.create(:type_feature) }
  let(:type_task) { FactoryGirl.create(:type_task) }
  let(:priority) { impediment.priority }
  let(:task) {
    FactoryGirl.build(:task, type: type_task,
                             project: project,
                             author: user,
                             priority: priority,
                             status: status1)
  }
  let(:feature) {
    FactoryGirl.build(:work_package, type: type_feature,
                                     project: project,
                                     author: user,
                                     priority: priority,
                                     status: status1)
  }
  let(:version) { FactoryGirl.create(:version, project: project) }

  let(:project) do
    project = FactoryGirl.create(:project, types: [type_feature, type_task])

    FactoryGirl.create(:member, principal: user,
                                project: project,
                                roles: [role])

    project
  end

  let(:status1) { FactoryGirl.create(:status, name: 'status 1', is_default: true) }
  let(:status2) { FactoryGirl.create(:status, name: 'status 2') }
  let(:type_workflow) {
    Workflow.create(type_id: type_task.id,
                    old_status: status1,
                    new_status: status2,
                    role: role)
  }
  let(:impediment) do
    FactoryGirl.build(:impediment, author: user,
                                   fixed_version: version,
                                   assigned_to: user,
                                   project: project,
                                   type: type_task,
                                   status: status1)
  end

  before(:each) do
    allow(Setting).to receive(:plugin_openproject_backlogs).and_return({ 'points_burn_direction' => 'down',
                                                                         'wiki_template'         => '',
                                                                         'card_spec'             => 'Sattleford VM-5040',
                                                                         'story_types'           => [type_feature.id.to_s],
                                                                         'task_type'             => type_task.id.to_s })

    login_as user

    status1.save
    project.save
    type_workflow.save

    feature.fixed_version = version
    feature.save

    impediment.blocks_ids = feature.id.to_s
    impediment.save
  end

  shared_examples_for 'impediment update' do
    it { expect(subject.author).to eql user }
    it { expect(subject.project).to eql project }
    it { expect(subject.fixed_version).to eql version }
    it { expect(subject.priority).to eql priority }
    it { expect(subject.status).to eql status2 }
    it { expect(subject.type).to eql type_task }
    it { expect(subject.blocks_ids).to eql blocks.split(/\D+/).map(&:to_i) }
  end

  shared_examples_for 'impediment update with changed blocking relationship' do
    it_should_behave_like 'impediment update'
    it { expect(subject.relations_to.direct.size).to eq(1) }
    it { expect(subject.relations_to.direct[0]).not_to be_new_record }
    it { expect(subject.relations_to.direct[0].to).to eql story }
    it { expect(subject.relations_to.direct[0].relation_type).to eql Relation::TYPE_BLOCKS }
  end

  shared_examples_for 'impediment update with unchanged blocking relationship' do
    it_should_behave_like 'impediment update'
    it { expect(subject.relations_to.direct.size).to eq(1) }
    it { expect(subject.relations_to.direct[0]).not_to be_changed }
    it { expect(subject.relations_to.direct[0].to).to eql feature }
    it { expect(subject.relations_to.direct[0].relation_type).to eql Relation::TYPE_BLOCKS }
  end

  subject do
    call = instance.call(attributes: { blocks_ids: blocks,
                                       status_id: status2.id.to_s })

    call.result
  end

  describe 'WHEN changing the blocking relationship to another story' do
    let(:story) do
      FactoryGirl.build(:work_package,
                        subject: 'another story',
                        type: type_feature,
                        project: project,
                        author: user,
                        priority: priority,
                        status: status1)
    end
    let(:blocks) { story.id.to_s }
    let(:story_version)  { version }

    before(:each) do
      story.fixed_version = story_version
      story.save!
    end

    describe 'WITH the story having the same version' do
      it_should_behave_like 'impediment update with changed blocking relationship'
      it { expect(subject).not_to be_changed }
    end

    describe 'WITH the story having another version' do
      let(:story_version) { FactoryGirl.create(:version, project: project, name: 'another version') }

      it_should_behave_like 'impediment update with unchanged blocking relationship'
      it 'should not be saved successfully' do
        expect(subject).to be_changed
      end
      it { expect(subject.errors[:blocks_ids]).to include I18n.t(:can_only_contain_work_packages_of_current_sprint, scope: [:activerecord, :errors, :models, :work_package, :attributes, :blocks_ids]) }
    end

    describe 'WITH the story beeing non existent' do
      let(:blocks) { '0' }

      it_should_behave_like 'impediment update with unchanged blocking relationship'
      it 'should not be saved successfully' do
        expect(subject).to be_changed
      end
      it { expect(subject.errors[:blocks_ids]).to include I18n.t(:can_only_contain_work_packages_of_current_sprint, scope: [:activerecord, :errors, :models, :work_package, :attributes, :blocks_ids]) }
    end
  end

  describe 'WITHOUT a blocking relationship defined' do
    let(:blocks) { '' }

    it_should_behave_like 'impediment update with unchanged blocking relationship'
    it 'should not be saved successfully' do
      expect(subject).to be_changed
    end

    it { expect(subject.errors[:blocks_ids]).to include I18n.t(:must_block_at_least_one_work_package, scope: [:activerecord, :errors, :models, :work_package, :attributes, :blocks_ids]) }
  end
end

# == Schema Information
#
# Table name: people
#
#  id                     :integer          not null, primary key
#  first_name             :string(255)
#  last_name              :string(255)
#  company_name           :string(255)
#  nickname               :string(255)
#  company                :boolean          default(FALSE), not null
#  email                  :string(255)
#  address                :string(1024)
#  zip_code               :integer
#  town                   :string(255)
#  country                :string(255)
#  gender                 :string(1)
#  birthday               :date
#  additional_information :text
#  contact_data_visible   :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  encrypted_password     :string(255)
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0)
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  name_mother            :string(255)
#  name_father            :string(255)
#  nationality            :string(255)
#  profession             :string(255)
#  bank_account           :string(255)
#  ahv_number             :string(255)
#  ahv_number_old         :string(255)
#  j_s_number             :string(255)
#  insurance_company      :string(255)
#  insurance_number       :string(255)
#

require 'spec_helper'

describe Person do
    
  let(:person) { role.person.reload }
  subject { person }
  
  it "is not valid without any names" do
    Person.new.should have(1).errors_on(:base)
  end
  
  it "company only with nickname is not valid" do
    Person.new(company: true, nickname: 'foo').should have(1).errors_on(:base)
  end
  
  it "company only with company name is valid" do
    p = Person.new(company: true, company_name: 'foo').should be_valid
  end
  
  it "real only with nickname is valid" do
    Person.new(company: false, nickname: 'foo').should be_valid
  end
  
  it "real only with company_name is not valid" do
    Person.new(company: false, company_name: 'foo').should have(1).errors_on(:base)
  end
  
  it "with login role requires email" do
    group = groups(:top_group)
    person = Person.new(last_name: 'Foo')
    
    person.should be_valid
    
    role = Group::TopGroup::Member.new
    role.group_id = group.id
    person.roles << role
    
    person.should have(1).error_on(:email)
  end
  
  it "can create person with role" do
    group = groups(:top_group)
    person = Person.new(last_name: 'Foo', email: 'foo@example.com')
    role = group.class.roles.first.new
    role.group_id = group.id
    person.roles << role
    
    person.save.should be_true
  end
  
  context "with one role" do
    let(:role) { Fabricate(Group::TopGroup::Leader.name.to_sym, group: groups(:top_group)) }
    
    its(:layer_groups) { should == [groups(:top_layer)] }
    
    it "has layer_full permission in top_group" do
      person.groups_with_permission(:layer_full).should == [groups(:top_group)]
    end
  end
  
  
  context "with multiple roles in same layer" do
    let(:role) do
       role1 = Fabricate(Group::BottomGroup::Member.name.to_sym, group: groups(:bottom_group_one_one))
       Fabricate(Group::BottomLayer::Leader.name.to_sym, group: groups(:bottom_layer_one), person: role1.person)
    end
    
    its(:layer_groups) { should == [groups(:bottom_layer_one)]}
    
    it "has layer_full permission in top_group" do
      person.groups_with_permission(:layer_full).should == [groups(:bottom_layer_one)]
    end
    
    it "has no layer_read permission" do
      person.groups_with_permission(:layer_read).should be_empty
    end
    
    it "only layer role is visible from above" do
      person.groups_where_visible_from_above.should == [groups(:bottom_layer_one)]
    end
    
    it "is not visible from above for bottom group" do
      g = groups(:bottom_group_one_one)
      g.people.visible_from_above(g).should_not include(person)
    end
    
    it "is visible from above for bottom layer" do
      g = groups(:bottom_layer_one)
      g.people.visible_from_above(g).should include(person)
    end
    
    it "preloads groups with the given scope" do
      p = Person.preload_groups.find(person.id)
      p.groups.to_set.should == [groups(:bottom_group_one_one), groups(:bottom_layer_one)].to_set
    end
    
    it "in_layer returns person for this layer" do
      Person.in_layer(groups(:bottom_group_one_one)).should == [person]
    end
    
    it "in_or_below returns person for above layer" do
      Person.in_or_below(groups(:top_layer)).should == [people(:top_leader), person]
    end
  end
  
  context "with multiple roles in different layers" do
    let(:role) do
       role1 = Fabricate(Group::TopGroup::Member.name.to_sym, group: groups(:top_group))
       Fabricate(Group::BottomLayer::Leader.name.to_sym, group: groups(:bottom_layer_one), person: role1.person)
    end
    
    its(:layer_groups) { should have(2).items }
    its(:layer_groups) { should include(groups(:top_layer), groups(:bottom_layer_one)) }
    
    it "has contact_data permission in both groups" do
      person.groups_with_permission(:contact_data).to_set.should == [groups(:top_group), groups(:bottom_layer_one)].to_set
    end
    
    it "both groups are visible from above" do
      person.groups_where_visible_from_above.to_set.should == [groups(:top_group), groups(:bottom_layer_one)].to_set
    end
    
    it "whole hierarchy may view this person" do
      person.above_groups_visible_from.to_set.should == [groups(:top_layer), groups(:top_group), groups(:bottom_layer_one)].to_set
    end
    
    it "in_layer returns person for this layer" do
      Person.in_layer(groups(:bottom_group_one_one)).should == [person]
    end
    
    it "in_or_below returns person for any layer" do
      Person.in_or_below(groups(:top_layer)).should == [people(:top_leader), person]
    end
  end
  
  context "with invisible role" do
    let(:group) { groups(:bottom_group_one_one) }
    let(:role) { Fabricate(Group::BottomGroup::Member.name.to_sym, group: group) }
    
    it "has not role that is visible from above" do
      person.groups_where_visible_from_above.should be_empty
    end
    
    it "is not visible from above without arguments" do
      group.people.visible_from_above.should_not include(person)
    end
    
    it "is not visible from above without arguments" do
      group.people.visible_from_above(group).should_not include(person)
    end
    
    it "is not visible from above in combination with other scopes" do
      Person.in_or_below(groups(:top_layer)).visible_from_above.should_not include(person)
    end
  end

  context "devise recoverable" do
    let(:group) { groups(:bottom_group_one_one) }
    let(:person) { Fabricate(Group::BottomGroup::Member.name.to_sym, group: group).person.reload }

    it "cannot reset password if we have no login permission" do
      person.send_reset_password_instructions.should be_false
    end
  end

end

# == Schema Information
#
# Table name: appointments
#
#  id            :integer          not null, primary key
#  role_id       :integer
#  user_id       :integer
#  individual_id :integer
#  created_at    :datetime
#  updated_at    :datetime
#

class Appointment < ActiveRecord::Base
  belongs_to :role
  belongs_to :user
  belongs_to :individual

  delegate :permissions, :to => :role

  after_initialize :assign_default_role, :if => proc{ |o| o.role.nil? }

  def assign_default_role
    self.role = Role::default
  end
end

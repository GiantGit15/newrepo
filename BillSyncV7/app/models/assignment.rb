# == Schema Information
#
# Table name: assignments
#
#  id               :integer          not null, primary key
#  hit_id           :integer
#  worker_id        :integer
#  status           :integer          default(0)
#  mt_assignment_id :string(255)
#  created_at       :datetime
#  updated_at       :datetime
#

class Assignment < ActiveRecord::Base
  belongs_to :worker
  belongs_to :hit
  has_many   :invoice_moderations
  has_many   :turk_transactions
  has_many   :surveys

end

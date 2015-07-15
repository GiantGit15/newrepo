# == Schema Information
#
# Table name: comments
#
#  id               :integer          not null, primary key
#  body             :text
#  worker_id        :integer
#  created_at       :datetime
#  updated_at       :datetime
#  mt_hit_id        :string(255)
#  mt_worker_id     :string(255)
#  mt_assignment_id :string(255)
#

class Comment < ActiveRecord::Base

  belongs_to :worker

  before_validation :set_worker
  validates :body, presence: true

  after_save :send_notification_email!

  private

  def send_notification_email!
    return true unless Hit.find_by(mt_hit_id: mt_hit_id)
    DefaultNotifier.new_comment(self).deliver
  end

  def set_worker
    self.worker = Worker.find_or_create_by(mt_worker_id: mt_worker_id)
  end
end

# == Schema Information
#
# Table name: approvals
#
#  id          :integer          not null, primary key
#  kind        :string(255)      default("regular"), not null
#  invoice_id  :integer
#  approver_id :integer
#  approved_at :datetime
#  created_at  :datetime
#  updated_at  :datetime
#

class Approval < ActiveRecord::Base
  KINDS = %w[regular accountant]

  before_save :set_approval_kind_to_invoice

  belongs_to :invoice, inverse_of: :approvals
  belongs_to :approver, class_name: "Individual", inverse_of: :approvals

  validates :approver, presence: true
  validates :kind, presence: true, inclusion: KINDS

  scope :of_kind, proc { |kind| where(kind: kind.to_s) }
  scope :by, proc { |who| where(approver: who) }

  def done?
    approved_at.present?
  end

  def finish
    done? and raise "Cannot double-approve"
    self.approved_at = Time.now
    self.save!
    self
  end

  private

  def set_approval_kind_to_invoice
    Rails.env.test? and return true
    invoice.update_column(:"#{kind}_approved", true)
    true
  end
end

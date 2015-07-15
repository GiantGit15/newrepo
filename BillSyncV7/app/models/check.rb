# == Schema Information
#
# Table name: checks
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  sent_date     :date
#  number        :string(255)
#  vendor_id     :integer
#  txn_id        :string(255)
#  time_created  :datetime
#  time_modified :datetime
#  edit_sequence :string(255)
#  txn_number    :string(255)
#  sync_qb       :boolean          default(FALSE)
#  created_at    :datetime
#  updated_at    :datetime
#

class Check < ActiveRecord::Base

  belongs_to :user
  belongs_to :vendor
  has_many :invoices

  scope :ready_to_sync, -> { where(sync_qb: true) }

  validates :user, :vendor, :number, :sent_date, presence: true
  validates :number, uniqueness: { scope: :user_id }

  def to_qb_xml!
    Checks::BillCheckPaymentBuilder.find(id).to_xml!
  end

  def update_from_qbd_response(params)
    update_attributes(sync_qb: false, txn_id: params["txn_id"],
      time_created: params["time_created"], time_modified: params["time_modified"],
      edit_sequence: params["edit_sequence"], txn_number: params["txn_number"],
      txn_id: params["txn_id"])
  end
end

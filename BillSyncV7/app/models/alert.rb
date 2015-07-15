# == Schema Information
#
# Table name: alerts
#
#  id               :integer          not null, primary key
#  created_at       :datetime
#  updated_at       :datetime
#  alertable_id     :integer
#  category         :integer
#  invoice_owner_id :integer
#  alertable_type   :string(255)
#  short_text       :text
#  large_text       :text
#  average          :decimal(, )
#  sms_text         :text
#

class Alert < ActiveRecord::Base
  belongs_to :alertable, polymorphic: true
  belongs_to :invoice_owner, class_name: 'Invoice', foreign_key: :invoice_owner_id
  has_many :sms_messages

  enum category: {
    invoice_increase_total: 0,
    new_line_item: 1,
    line_item_quantity: 2,
    line_item_price_increase: 3,
    new_vendor: 4,
    duplicate_invoice: 5,
    manual_adjustment: 6,
    resending_payment: 7,
    no_location: 8,
    processing_items: 9
  }

  validates :invoice_owner_id, presence: true

  # validates_uniqueness_of :invoice_owner_id, scope: [:alertable_type, :alertable_id]

  def self.uniq_short_texts
    pluck(:short_text).uniq
  end

  def self.build_resending_payment(invoice)
    new(alertable: invoice, short_text: "Resending Payment", category: 7)
  end
end

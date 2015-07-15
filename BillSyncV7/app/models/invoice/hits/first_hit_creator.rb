# == Schema Information
#
# Table name: hits
#
#  id          :integer          not null, primary key
#  status      :integer          default(0)
#  mt_hit_id   :string(255)
#  url         :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  hit_type    :integer          default(0)
#  reward      :decimal(8, 2)    default(0.0)
#  invoice_id  :integer
#  submited    :boolean          default(FALSE)
#  page_number :integer          default(1)
#  title       :string(255)
#

# Creates a HIT Model and a HIT on the MT API from an INVOICE first review.
class Hits::FirstHitCreator < Hit

  validate :invoice, presence: true

  after_create :create_mt_hit
  after_create :set_hit_attributes
  after_create :create_invoice_moderations!

  def self.build_from(invoice = nil)
    builder = new(invoice: invoice)

    builder
  end

  private

  def create_invoice_moderations!
    return false unless InvoiceModerations::ModerationCreator.create_two!(invoice, self, :default) # Todo fix return value of this.
    invoice.hits << self
    true
  end

  def hit_title
    if Rails.env.staging?
      "STAGING: Extract summary information from 1 invoice"
    else
      "Extract summary information from 1 invoice"
    end
  end

  def description(count = 0)
    "Extract the vendor, amout due, taxes, due date, invoice number and account number from 1 invoice."
  end

  def set_hit_attributes
    super
    save
  end
end

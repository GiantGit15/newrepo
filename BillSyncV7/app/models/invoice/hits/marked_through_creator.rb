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

# Creates a HIT Model and a HIT on the MT API from an for marked through invoices
class Hits::MarkedThroughCreator < Hit

  validates :invoice, presence: true

  before_validation :set_hit_type
  after_create :create_mt_hit
  after_create :set_hit_attributes
  after_create :create_invoice_moderations!

  private

  def create_invoice_moderations!
    InvoiceModerations::ModerationCreator.create_two!(invoice, self, :for_marked_through) # Todo fix return value of this.
    true
  end

  def hit_title
    if Rails.env.staging?
     "STAGING: Calculate amount due based on changes for 1 invoice"
    else
     "Calculate amount due based on changes for 1 invoice"
    end
  end

  def description(count = 0)
    "Either the quantity or price of an item on this invoice has been manually adjusted. Please re-calculate the amount due based on these adjustments."
  end

  def set_hit_type
    self.hit_type = :marked_through
  end

  def set_hit_attributes
    super
    save
  end
end

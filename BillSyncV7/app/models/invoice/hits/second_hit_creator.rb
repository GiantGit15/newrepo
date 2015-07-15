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

# Creates a HIT Model and a HIT on the MT API from an INVOICE SECOND review.
class Hits::SecondHitCreator < Hit
  attr_accessor :mt_hit

  validates :invoice, presence: true

  before_save :set_hit_type
  after_create :create_mt_hit
  after_create :set_hit_attributes
  after_create :create_invoice_moderation!

  private

  def create_invoice_moderation!
    InvoiceModerations::ModerationCreator.create_one!(invoice, self, :for_second_review)
    true
  end

  def hit_title
    # "Heroku Development #{HIT_VERSION}: Extract summary information from some-number invoice"
    if Rails.env.staging?
      "STAGING: Extract summary information from 1 invoice"
    else
      "Extract summary information from 1 invoice"
    end
  end

  def description(field_name = "")
    "Extract the #{field_name.to_s} from the invoice s"
  end

  def num_assignments
    1 # Per hit
  end

  def set_hit_type
    self.hit_type = :second_review
  end

  def set_hit_attributes
    super
    save
  end
end

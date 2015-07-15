# == Schema Information
#
# Table name: invoices
#
#  id                       :integer          not null, primary key
#  number                   :string(255)
#  vendor_id                :integer
#  amount_due               :decimal(, )
#  tax                      :decimal(, )
#  other_fee                :decimal(, )
#  due_date                 :date
#  resale_number            :string(255)
#  account_number           :string(255)
#  delivery_address1        :string(255)
#  delivery_address2        :string(255)
#  delivery_address3        :string(255)
#  delivery_city            :string(255)
#  delivery_state           :string(255)
#  delivery_zip             :string(255)
#  date                     :date
#  invoice_total            :boolean
#  new_item                 :boolean
#  line_item_quantity       :boolean
#  unit_price               :boolean
#  created_at               :datetime
#  updated_at               :datetime
#  user_id                  :integer
#  invoice_moderation       :boolean          default(FALSE)
#  reviewed                 :boolean          default(FALSE)
#  pdf_file_name            :string(255)
#  pdf_content_type         :string(255)
#  pdf_file_size            :integer
#  pdf_updated_at           :datetime
#  payment_send_date        :date
#  payment_date             :date
#  act_by                   :date
#  email_body               :text
#  paid_with                :integer
#  status                   :integer          default(1)
#  source                   :integer          default(0)
#  check_number             :integer
#  check_date               :date
#  qb_id                    :integer
#  sync_token               :integer
#  source_email             :string(255)
#  deferred_date            :date
#  invoice_survey_id        :integer
#  is_invoice               :boolean
#  vendor_present           :boolean
#  address_present          :boolean
#  amount_due_present       :boolean
#  bank_information_present :boolean
#  line_items_count         :integer
#  is_marked_through        :boolean
#  survey_agreement         :boolean
#  stated_date              :date
#  processed_by_turk        :boolean          default(FALSE)
#  address_id               :integer
#  failed_items             :integer
#  bank_name                :string(255)
#  qb_d_id                  :string(255)
#  sync_qb                  :boolean          default(FALSE)
#  edit_sequence            :string(255)
#  txn_id                   :string(255)
#  synced_payment           :boolean          default(FALSE)
#  search_on_qb             :boolean          default(FALSE)
#  txn_number               :integer
#  bill_paid                :boolean          default(FALSE)
#  expense_account_id       :integer
#  qb_class_id              :integer
#  has_items                :boolean          default(FALSE)
#  accountant_approved      :boolean          default(FALSE)
#  regular_approved         :boolean          default(FALSE)
#  pdf_total_pages          :integer          default(1)
#  qb_d_deleted_at          :datetime
#  resending_payment_at     :datetime
#  qb_bill_paid_at          :datetime
#  request_number           :integer          default(0)
#  bill_payment_txn_id      :string(255)
#  marked_as_paid           :boolean          default(FALSE)
#  billsync_created_at      :datetime
#  check_id                 :integer
#  xero_id                  :string(255)
#

# Update Invoice fields from the results obtained by the FIRST invoice moderations workers.
class Invoice::AsFirstReview < Invoice

  validates :amount_due, :vendor_id, presence: true # tax and due_date missing here
  validate :valid_vendor

  before_save :set_delivery_date
  after_commit :pay_workers!
  after_commit :set_vendor_status

  private

  def pay_workers!
    invoice_moderations.default.includes(:worker).collect(&:worker).each do |worker|
      ::Workers::Payment.payment_for(worker, hits.first_review.first.reward, true)
    end
    true
  end

  def set_status
    info_complete!
    true
  end

  def valid_vendor
    return unless selected_invoice_moderation && selected_invoice_moderation.vendor_id
    if vendor = Vendor.find(selected_invoice_moderation.vendor_id)
      errors.add(:vendor_id, "invalid vendor") unless vendor.valid_vendor?
    else
      errors.add(:vendor_id, "can't find this vendor")
    end
  end

  def set_vendor_status
    vendor.by_user! unless vendor.by_user?
    true
  end
end

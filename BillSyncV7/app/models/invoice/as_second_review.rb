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

# Update Invoice from second invoice moderation Review.
class Invoice::AsSecondReview < Invoice
  attr_accessor :input_type, :worker_im, :im_for_update

  validates :input_type, :im_for_update, presence: true
  validates :vendor_id, presence: true, if: :for_vendor?
  validates :amount_due, presence: true, if: :for_amount?

  before_validation :pick_im_by_worker_score
  before_validation :update_field_from_im_for_update
  before_save :set_delivery_date
  before_update :set_fields_from_invoice_moderation

  after_update :pay_workers!
  after_update :clear_hit!

  after_commit :set_vendor_status

  def self.update_with(invoice_moderation, input_type)
    builder = find(invoice_moderation.invoice.id)
    builder.im_for_update = invoice_moderation
    builder.input_type = input_type
    builder.save
  end

  private

  def for_vendor?
    input_type == :vendor_id
  end

  def for_amount?
    input_type == :amount_due
  end

  def update_field_from_im_for_update
    if for_vendor? && !vendor_id.present?
      vd = Vendor.find(im_for_update.vendor_id)
      self.vendor_id = vd.parent_id ? vd.parent_id : vd.id
    elsif for_amount? && !amount_due.present?
      self.amount_due = im_for_update.amount_due unless has_marked_through_hit?
    end
  end

  def pay_workers!
    hits.each do |hit|
      ::Workers::Payment.payment_for(@selected_worker, hit.reward, true)
      ::Workers::Payment.payment_for(im_for_update.worker, hit.reward, true)
    end
    true
  end

  def clear_hit!
    if new_hit_id = invoice_moderations.second_review.first.try(:hit_id)
      ::Hits::Review.complete!(new_hit_id)
    end
    true
  end

  def pick_im_by_worker_score
    @selected_worker = ::Workers::Comparator.build_with_invoice_moderation(invoice_moderations).comparate_by_score
    @selected_invoice_moderation = invoice_moderations.find_by(worker_id: @selected_worker.id)
  end

  def set_status
    begin
      info_complete!
    rescue
    end
    true
  end

  def set_vendor_status
    vendor.by_user! unless vendor.by_user?
    true
  end
end

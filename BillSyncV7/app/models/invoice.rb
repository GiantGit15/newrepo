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

class Invoice < ActiveRecord::Base
  include AASM
  include ActionView::Helpers::TextHelper

  attr_accessor :selected_invoice_moderation, :from_user, :resend_payment,
                :resending_payment, :transactions

  belongs_to :user, inverse_of: :invoices
  belongs_to :vendor, inverse_of: :invoices
  belongs_to :survey_hit, class_name: 'Hit', inverse_of: :invoice_surveys, foreign_key: :invoice_survey_id
  has_many :hits
  has_many :uploads, inverse_of: :invoice
  has_many :invoice_moderations
  has_many :alerts, as: :alertable
  has_many :total_alerts, inverse_of: :invoice_owner, class_name: 'Alert', foreign_key: :invoice_owner_id
  has_one :sms_thread
  has_many :sms, through: :sms_thread
  has_many :surveys
  has_many :addresses, as: :addressable
  has_many :invoices_sms_threads
  has_many :sms_threads, through: :invoices_sms_threads
  has_many :invoice_pages
  has_many :invoice_transactions, inverse_of: :invoice
  has_many :turk_transactions

  belongs_to :ship_to_address, class_name: 'Address', foreign_key: :address_id

  has_many :approvals, inverse_of: :invoice

  belongs_to :expense_account, class_name: "Account", foreign_key: :expense_account_id
  belongs_to :qb_class
  belongs_to :check

  scope :by_status, ->(*st) { where(status: st) }
  scope :without_moderations, -> { where(invoice_moderation: false) }
  scope :by_vendor, ->(vendor_id) { where(vendor_id: vendor_id)}
  scope :by_period, -> (start_date, end_date) { where("date >= ? AND date <= ?", (start_date || 3.months.ago.to_date), (end_date || Date.today) ) }

  accepts_nested_attributes_for :vendor, :invoice_transactions

  has_attached_file :pdf, s3_protocol: 'https'
  has_paper_trail

  validates_attachment :pdf, content_type: { content_type: ["application/pdf"] }

  delegate :by_billsync?, to: :vendor, allow_nil: true

  # after_initialize :build_default
  validate :billsync_vendor, on: :update
  before_save :recalculate_due_date
  before_save :set_act_by
  before_save :set_payment_send_date
  before_save :watch_for_alerts
  before_save :clear_amount_due
  before_save :recalculate_status
  before_save :build_transactions
  before_save :set_sync_qb
  after_save :save_tax_item
  after_save :save_other_fees_item
  after_save :run_alerts_clearer
  after_save :create_dup_invoice
  after_save :calculate_item_average
  after_save :update_intercom, if: :user
  # after_save :sync_to_accounting_system!
  after_update :recalculate_default_invoice_transaction
  after_create :create_default
  after_create :create_pdf
  after_create :after_create_sync
  after_create :update_user_first_bill_added, if: :user
  after_create :set_initial_status
  after_commit :sync_with_quickbooks, if: :user

  before_destroy :expire_hits!

  delegate :locations_feature, to: :user, prefix: true

  enum paid_with: [:wire, :check]

  enum status: {
    received: 1,
    in_process: 2,
    need_information: 3,
    ready_for_payment: 4,
    payment_queue: 5,
    check_sent: 6,
    wire_sent: 7,
    archived: 8,
    issue_check: 9,
    issue_wire: 10,
    deleted: 11,
    disputed: 12,
    paid_by_billsync: 13
  }

  enum source: [:by_app, :by_email]

  aasm column: :status, enum: true do
    state :received, initial: true
    state :in_process
    state :need_information
    state :ready_for_payment
    state :payment_queue
    state :check_sent
    state :wire_sent
    state :archived
    state :issue_check
    state :issue_wire
    state :deleted
    state :disputed
    state :paid_by_billsync

    event :extract_data do # 2
      transitions from: :received, to: :in_process
    end

    event :missing_fields do  # 3
      after do
        sent_notifications
      end
      transitions from: [:in_process, :received], to: :need_information, guard: [:missing_any_fields?]
    end

    event :information_completed do   # 4
      before do
        set_delivery_date
        recalculate_due_date
      end
      after do
        sync_with_quickbooks
        sent_notifications
      end
      transitions from: [:in_process, :received, :need_information], to: :ready_for_payment, guard: [:filled_vendor_fields?, :filled_amount_due?]
    end

    event :information_completed_to_queue do  # 5
      before do
        set_delivery_date
        recalculate_due_date
      end
      after do
        sync_with_quickbooks
        set_payment_send_date
        sent_notifications
      end
      transitions from: [:in_process, :received, :need_information], to: :payment_queue, guard: [:filled_vendor_fields?, :filled_amount_due?]
    end

    event :ready_to_pay do   # 6
      after do
        sync_with_quickbooks
      end
      transitions from: :need_information, to: :ready_for_payment, guard: [:filled_vendor_fields?, :filled_amount_due?]
    end

    event :ready_to_pay_to_payment_queue do # 7
      after do
        set_payment_send_date
        sync_with_quickbooks
        update_user_first_bill_paid
      end
      transitions from: [:need_information, :ready_for_payment], to: :payment_queue, guard: [:filled_vendor_fields?, :filled_amount_due?]
    end

    event :mark_as_paid do # 8, 12, 18
      before do
        qb_make_payment! unless need_information?
        sync_to_qb_desktop_payment!
      end
      transitions from: [:need_information, :ready_for_payment, :payment_queue], to: :archived
    end

    event :mark_as_deleted do   # 9, 13, 19
      before do
        clear_duplicate_alerts
        mark_as_qb_deleted!
      end
      transitions from: [:need_information, :ready_for_payment, :payment_queue, :received, :in_process], to: :deleted
    end

    event :mark_with_dispute do  # 10, 14, 20
      transitions from: [:need_information, :ready_for_payment, :payment_queue], to: :disputed
    end

    event :pay_invoice do   # 11
      after do
        set_payment_send_date
      end
      transitions from: :ready_for_payment, to: :payment_queue
    end

    event :cancel_payment do # 15
      transitions from: :payment_queue, to: :ready_for_payment
    end

    event :check_send do  # 16
      before do
        set_paid_with_check
        set_payment_date
        qb_make_payment!
      end
      transitions from: :payment_queue, to: :check_sent
    end

    event :wire_send do # 17
      before do
        update_column(:edit_sequence, nil)
        set_paid_with_wire
        set_payment_date
        qb_make_payment!
        sync_to_qb_desktop_payment!
      end
      transitions from: :payment_queue, to: :wire_sent
    end

    event :mark_as_paid_by_wire do  # 21
      transitions from: :wire_sent, to: :paid_by_billsync
    end

    event :mark_as_paid_by_check do  # 22
      transitions from: :check_sent, to: :paid_by_billsync
    end

    event :issue_wire_back do  # 23, 25
      transitions from: :paid_by_billsync, to: [:issue_wire, :missing_fields]
    end

    event :issue_check_back do   # 24, 26
      transitions from: :paid_by_billsync, to: [:issue_check, :missing_fields]
    end

    event :dispute_to_missing_fields do # 27
      transitions from: :disputed, to: :missing_fields
    end

    event :dispute_to_ready_for_payment do # 28
      transitions from: :disputed, to: :ready_for_payment
    end

    event :dispute_to_ready_for_payment do # 29
      after do
        set_payment_send_date
      end
      transitions from: :disputed, to: :payment_queue
    end
  end

  def self.paid_last_7_days
    where("invoices.status IN (6)").where("invoices.payment_date >= ? AND invoices.payment_date <= ?", 1.week.ago.at_beginning_of_day, Date.today).sum(:amount_due)
  end

  def self.pending_next_7_days
    pending_payments_between(Date.today, 1.week.from_now)
  end

  def self.pending_next_14_days
    pending_payments_between(Date.today, 2.weeks.from_now)
  end

  def self.pending_next_month
    pending_payments_between(Date.today, 1.month.from_now)
  end

  def self.pending_payments_between(start_d, end_d)
    where("invoices.status IN (4,5)").where("payment_send_date >= ? AND payment_send_date <= ?", start_d, end_d).sum(:amount_due)
  end

  def sync_with_quickbooks(async = true)
    if async
      InvoiceSyncWorker.perform_async(id)
    else
      QuickbooksSync::Invoices::Bill.find(id).sync!
    end
    true
  end

  def missing_any_fields?
    ![filled_vendor_fields?, filled_amount_due?].all?
  end

  def missing_vendor_fields?
    return true unless vendor && vendor.name.present?
    !vendor.wire_or_payment_fields_filled?
  end

  def filled_vendor_fields?
    !missing_vendor_fields?
  end

  def amount_due_missing?
    amount_due.blank? || amount_due.zero?
  end

  def all_alerts
    [total_alerts, alerts.duplicate_invoice].flatten
  end

  def all_alert_short_text
    [total_alerts.pluck(:short_text), alerts.duplicate_invoice.pluck(:short_text)].flatten
  end

  def humanized_alert_text
    count = total_alerts.count
    return unless count > 0
    "#{count} alert".pluralize(count)
  end

  def filled_amount_due?
    !amount_due_missing?
  end

  def set_paid_with_wire
    self.paid_with = 0
  end

  def set_paid_with_check
    self.paid_with = 1
    true
  end

  def self.one_invoice_moderation
    invoice_moderations.not_submited.first
  end

  def self.archived_invoices
    by_status(6,7,8,13)
  end

  def self.counts
    {
      dashboard_count: by_status(3,4).where('deferred_date IS NULL or deferred_date <= ?', Date.today).count,
      regular_view: by_status(3, 4).count
    }
  end

  def mark_as_qb_deleted!
    update_column(:sync_qb, true)
    return true unless qb_id && user.intuit_authentication?
    model = QuickbooksSync::Invoices::Bill.find(id)
    qb_service_bill.delete(model.send(:qb_invoice_model))
  end

  def qb_delete_xml
    deletion_type = resending_payment_at.present? || bill_payment_txn_id ? "BillPaymentCheck": "Bill"
    this_id = resending_payment_at.present? || bill_payment_txn_id ? bill_payment_txn_id : txn_id
    {
      txn_del_rq: {
        xml_attributes: { "requestID" => id },
        txn_del_type: deletion_type,
        "TxnID" => this_id
      }
    }
  end

  def qb_service_bill
    return @qb_service_bill if @qb_service_bill
    @qb_service_bill ||= Quickbooks::Service::Bill.new
    @qb_service_bill.access_token = user.user_oauth_intuit
    @qb_service_bill.company_id = user.realm_id

    @qb_service_bill
  end

  def csv_fields
    [number, due_date.try(:strftime, '%m/%d/%Y'), amount_due, user.reload.check_number, Date.today.strftime("%m/%d/%Y")]
  end

  def hits_active?(except = nil)
    hit_types = [hits.hit_types['for_survey'], hits.hit_types['for_address']]
    hit_types.push(hits.hit_types[except]) if except
    !hits.where.not(hit_type: hit_types).pluck(:submited).all?
  end

  def other_invoices_with_same_vendor
    vendor.present? ? vendor.invoices.where.not(id: id) : Invoice.none
  end

  def get_dupe_invoice
    other_invoices_with_same_vendor.order("created_at DESC").not_deleted.where(number: number.to_s).first or
    other_invoices_with_same_vendor.order("created_at DESC").not_deleted.where(amount_due: amount_due, date: date).first
  end

  def self.initial_sync!
    where(status: [4,5]).each do |invoice|
      begin
        invoice.sync_with_quickbooks(true)
      rescue => e
        puts "> EXCEPTION ON INVOICES #{e.messages}"
      end
    end
  end

  def self.bills_count_by_status
    if by_status(3,4,9,10).count >= 9999
      '9999+'
    elsif by_status(3,4,9,10).count == 0
      'DONE!'
    else
      by_status(3,4,9,10).count
    end
  end

  def self.by_deferred_date
    where('deferred_date IS NULL or deferred_date <= ?', Date.today)
  end

  def self.order_by_act_by
    order('act_by DESC')
  end

  def update_deferred_date(date_string)
    new_date = case date_string
    when 'TOMORROW' then Date.tomorrow
    when 'NEXT_WEEK' then Date.today.next_week
    when 'NEXT_MONTH' then Date.today.next_month
    end
    update_attributes(deferred_date: new_date)
  end

  def self.not_deleted
    where.not(status: 11)
  end

  def self.less_than_30
    where('due_date >= ?', 1.month.ago).by_status(1, 2, 3, 4, 5)
  end

  def self.more_than_30
    where('due_date < ?', 1.month.ago.to_date).by_status(1, 2, 3, 4, 5)
  end

  def self.last_ten
    limit(10).order('created_at DESC')
  end

  def survey_attributes
    {
      id: id, pdf_url: pdf_url, user_addresses: user.formated_addresses,
      locations_feature: user.locations_feature, pdf_total_pages: pdf_total_pages
    }
  end

  def uploaded_images
    uploads.collect {|upload| { id: upload.id, url: upload.image.try(:url), thumbnail: upload.image.try(:url, :thumbnail)} }
  end

  def try_to_create_survey_hit!
    return info_complete! if [filled_vendor_fields?, filled_amount_due?].all?
    return unless hits.for_survey.any?
    Mturk::Surveys::Hits::Creator.try_to_create_hit
    true
  end

  def humanized_status
    case
    when received? then "Received"
    when in_process? then "In data extraction process"
    when need_information? then "Missing Payments fields"
    when ready_for_payment? then "Ready for payment"
    when payment_queue? then "In queue for payment"
    when check_sent? then "Check sent"
    when wire_sent? then "Wire sent"
    when archived? then "Mark as Paid"
    when issue_check? then "Issue: Wire came back"
    when issue_wire? then "Issue: Wire came back"
    when deleted? then "Deleted Invoice"
    when disputed? then "In dispute"
    when paid_by_billsync? then "Paid by billSync"
    end
  end

  def comparation_humanized_status
    case
    when ready_for_payment? then 'This bill is ready for payment.'
    when need_information? then "This bill need information"
    when payment_queue? then "This bill is on the payment queue"
    when archived? then "This bill was paid on #{payment_date.try(:strftime, '%m-%d')}"
    when deleted? then "This bill was deleted"
    when disputed? then "This bill is in dispute"
    when paid_by_billsync? then "This bill was paid on #{payment_date.try(:strftime, '%m-%d')}"
    end
  end

  def recalculate_due_date
    return true if by_billsync?
    if from_user && due_date.present? && due_date_changed? && status_was != 'need_information'
      return true
    end
    return clear_due_date unless vendor
    if vendor.keep_due_date?
      self.due_date = created_at
    else
      vendor_default_due_date
    end
    self.due_date || true
  end

  def pdf_url
    if !pdf.path.nil?
      pdf_local_path = pdf.url
    end
    return pdf_local_path if Rails.env.development?
    pdf? ? s3_url : pdf.url
  end

  def s3_url
    base_url = "https://billsync1.s3.amazonaws.com/invoices/"
    path = pdf.url.split('billsync1/invoices/')
    path.shift
    path.unshift(base_url)
    path.join
  end

  def to_sms
    response = "#{vendor.name} has a bill for $#{'%.2f' % amount_due}."
    response << "There are alerts for #{all_alert_short_text.uniq.to_sentence.downcase}." if all_alerts.present?
    response << " Would you like to pay this bill? 'y' for yes, 'd' to defer, 'p' to mark as paid, or 't' to crumple up and toss."
    response
  end

  def set_initial_status
    if vendor && vendor.by_billsync?
      update_column(:status, 5)
    elsif missing_any_fields? && [amount_due_changed?, vendor_id_changed?, due_date_changed?, number_changed?, date_changed?].any?
      need_information! unless uploads.any? || need_information?
    elsif [filled_vendor_fields?, filled_amount_due?].all?
      info_complete!
    end
    true
  end

  def set_fields_from_invoice_moderation
    InvoiceModeration::FIELDS.each do |field|
      unless self.send(field).present?
        unless field == :amount_due && has_marked_through_hit?
          self.send("#{field.to_s}=", selected_invoice_moderation.send(field))
        end
      end
    end
  end

  def workers
    invoice_moderations.collect(&:worker).compact
  end

  def create_pdf
    PdfWorker.perform_async(id) unless Rails.env.test?
    true
  end

  def default_item
    return false unless vendor && vendor.default_item
    invoice_transactions.default_invoice_transaction(vendor.default_item.id).present? && persisted?
  end

  def get_default_item
    return nil unless vendor
    invoice_transactions.default_invoice_transaction(vendor.default_item.id)
  end

  def info_complete!
    begin
      return true if ready_for_payment? || payment_queue?
      vendor.autopay_active? ? information_completed_to_queue! : information_completed!
    rescue
    end
  end

  def has_marked_through_hit?
    hits.marked_through.present?
  end

  def marked_thourgh_submited?
    has_marked_through_hit? && hits.marked_through.first.submited?
  end

  def valid_invoice?
    return false unless user && vendor
    [user.valid_user?, vendor.wire_or_payment_fields_filled?].all?
  end

  def is_a_valid_invoice?
    [filled_vendor_fields?, filled_amount_due?].all?
  end

  def to_qb_xml
    return qb_delete_xml if [deleted?, resending_payment_at?].any? && txn_id
    return query_qb_desktop if should_query?
    update_or_create_xml_qb
  end

  def should_query?
    return false unless txn_id
    return true if (search_on_qb || !invoice_transactions.pluck(:txn_line_id).all?(&:present?)) && qb_bill_paid_at?
    false
  end

  def update_or_create_xml_qb
    sync_type = txn_id ? :bill_mod : :bill_add
    {
      "#{sync_type}_rq".to_sym => {
        xml_attributes: { "requestID" => id },
        sync_type => qb_xml_attributes
      }
    }
  end

  def qb_xml_attributes
    hash = {}
    hash[:txn_id] = txn_id if txn_id
    hash[:edit_sequence] = edit_sequence if edit_sequence && txn_id
    hash[:vendor_ref] = { "ListID" => vendor.qb_d_id }
    hash["APAccountRef"] = { "ListID" => vendor.liability_account.qb_d_id } if vendor && vendor.liability_account && vendor.liability_account.qb_d_id
    hash[:txn_date] = date.present? && date.is_a?(Date) ? date : created_at.to_date
    hash[:due_date] = due_date.present? && due_date.is_a?(Date) ? date : created_at.to_date
    hash[:ref_number] = number
    hash[:memo] = "via web app - billSync"

    key = txn_id ? :expense_line_mod : :expense_line_add
    hash[key] = invoice_transactions.order('order_number ASC').collect(&:to_qb_item_line).compact
    hash
  end


  def query_qb_desktop
    query = {xml_attributes: { "requestID" => id }}
    query["TxnID"] = txn_id
    query[:include_line_items] = true
    {
      bill_query_rq: query
    }
  end

  def sync_with_quickbooks_desktop(should_save = false)
    if ready_to_sync?
      if should_save
        update_column(:sync_qb, true)
      else
        self.sync_qb = true
      end
    else
      sync_other_items
    end
    true
  end

  def create_line_items_hit
    return true unless amount_due.present?
    return true unless filled_vendor_fields?
    Mturk::LineItems::Hits::Creator.create_with(self)
    true
  end

  def approve_by who, kind
    approvals.of_kind(kind).by(who).first_or_initialize.finish
  end

  def update_expense_account
    update_most_valued_association :expense_account_id
  end

  def update_qb_class
    update_most_valued_association :qb_class_id
  end

  def invoice_pages_result_for(page_number = 1)
    invoice_pages.where(page_number: page_number).pluck(:line_items_count)
  end

  def comparation_result_for_page(page_number)
    array = invoice_pages_result_for(page_number).compact
    found = array.find {|e| array.count(e) > 1 }
    return found if found && found > 0
    (array.sum / array.length.to_f).round rescue 0
  end

  def can_create_hit_for_page?(page_number)
    array = invoice_pages_result_for(page_number).compact
    return false if array.count(0) > 1
    return false unless array.size > 1
    result = (array.sum / array.length.to_f).round
    result > 0
  end

  def create_hit
    return false if hits.first_review.present?
    ::Hits::FirstHitCreator.build_from(self).save
  end

  def reset_mt_turk!
    surveys.destroy_all
    invoice_moderations.destroy_all
    hits.destroy_all
    invoice_transactions.destroy_all
    invoice_pages.destroy_all
    turk_transactions.destroy_all
    update_columns(invoice_survey_id: nil, status: 1, amount_due: nil,
      vendor_id: nil, date: nil, due_date: nil, number: nil)
  end

  def vendor
    val = super
    val.try(:parent) || val
  end

  def pay_now!
    return false unless [filled_vendor_fields?, filled_amount_due?].all?
    next_payment_date = get_next_payment_date
    update_columns(status: 5, payment_send_date: next_payment_date)
    touch
  end

  def get_next_payment_date
    date = Date.today
    if date.monday? || date.thursday? && Time.now.hour < 13
      return date
    end

    while ![date.monday?, date.thursday?].any?
      date = date.next
    end
    date
  end

  def total_line_items
    invoice_transactions.not_default.sum(:total)
  end

  def recalculate_default_invoice_transaction
    return true unless vendor && vendor.default_item
    invoice_transactions.default_invoice_transaction(vendor.default_item.id).save
    true
  end

  def to_bill_payment_check_attribute
    { "TxnID" => txn_id, payment_amount: ('%.2f' % amount_due.try(:to_f) || 0) }
  end

  def xero_payment!
    ::XeroSync::Invoices::Invoice.find(id).make_payment!
  end

  protected

  def update_most_valued_association column
    most_valued_id = line_items
      .where.not(column => nil)
      .group(column)
      .select("#{column}, SUM(total) AS total_of_account")
      .order("total_of_account DESC")
      .first.try(:[], column)

    update_column column, most_valued_id
  end

  def set_act_by
    return true unless due_date.present?
    self.act_by = due_date - 5.days
  end

  def recalculate_status
    return true unless from_user
    if vendor && vendor.allways_mark_as_paid? && !archived?
      self.status = "archived"
      return true
    end

    if [filled_vendor_fields?, filled_amount_due?].all? && [received?, need_information?].any?
      create_line_items_hit
      create_item_alert if status_was == "need_information"
      self.status = vendor.autopay_active? ? 'payment_queue' : 'ready_for_payment'
    elsif [ready_for_payment?, payment_queue?].any? && missing_any_fields?
      return true if hits_active?
      self.status = 'need_information'
    end
    true
  end

  def create_item_alert
    Alerts::AlertCreator.create({invoice_owner: self, category: :processing_items, alertable: self})
  end

  def vendor_default_due_date
    if vendor.pay_day_of_month?
      self.due_date = vendor.pay_day_of_month_date
    elsif vendor.pay_after_bill_received?
      n_day = vendor.after_recieved || 1
      n_date = n_day.business_day.after(self.date || created_at.to_date || Date.today).to_date

      self.due_date = n_date <= Date.today ? n_date.next_month : n_date
    elsif vendor.pay_weekly?
      date = Date.today
      self.due_date = date += 1 + ((Vendor.auto_pay_weeklies[vendor.auto_pay_weekly] - date.wday) % 7)
    end
    if vendor.pay_before_due_date?
      self.deferred_date = vendor.set_pay_before_due_date(due_date, created_at)
    elsif vendor.pay_after_due_date?
      self.deferred_date = vendor.set_pay_after_due_date(due_date, created_at)
    end
  end

  def clear_due_date
    self.due_date = nil
    true
  end

  def clear_amount_due
    return true unless from_user
    return true unless amount_due.present? && amount_due.zero?
    self.amount_due = nil
  end

  def user_default_due_date
    begin
      self.due_date = date + user.default_due_date.days
    rescue
    end
  end

  def set_payment_send_date
    return true unless self.due_date.present? && payment_queue?
    return true if payment_date.present?
    self.payment_send_date = DateCalculatorService.new(due_date, 4).calculate!.to_date
    true
  end

  def watch_for_alerts
    Alerts::InvoiceAlertObserver.new(self).watch_for_all if persisted?
    true
  end

  def expire_hits!
    hits.each do |hit|
      hit.expire!
      hit.destroy
    end
    true
  end

  def set_delivery_date
    return true if date.present?
    self.date = created_at.to_time
    true
  end

  def create_dup_invoice
    return true unless resend_payment.present?
    self.resend_payment = nil
    self.resending_payment = true
    total_alerts << Alert.build_resending_payment(self)
    update_columns(sync_qb: true, resending_payment_at: DateTime.now)
    true
  end

  def set_payment_date
    self.payment_date = Date.today
    true
  end

  def qb_make_payment!
    if user.intuit_authentication?
      QuickbooksSync::Invoices::BillPayment.find(id).sync!
    elsif user.quickbooks_desktop_connection?
      self.sync_qb = true
    end
    true
  end

  def sent_notifications
    return unless source_email.present?
    Notifier.bill_processed(self).deliver
  end

  def calculate_item_average
    return true unless vendor
    invoice_transactions.each do |it|
      if vendor_id_changed?
        calculate_average_for(it, :price, :average_price)
        calculate_average_for(it, :quantity, :average_volume)
        next
      end
      next if !it.average_price.zero?
      next if !it.average_volume.zero?
      calculate_average_for(it, :price, :average_price)
      calculate_average_for(it, :quantity, :average_volume)
    end
  end

  def calculate_average_for(invoice_transaction, type, item_attribute)
    starting_date = (date || created_at) - 12.weeks
    query = invoice_transaction.line_item.invoice_transactions.joins(:invoice).where('invoices.date >= ? OR invoices.date = ?', starting_date, nil)
    collection = query.pluck(type).compact
    return unless collection.any?
    total = sum(collection)
    average = total / collection.size.to_f
    return if average.zero?
    return unless average && invoice_transaction.send(type)
    value = ((invoice_transaction.send(type).to_f - average) / average) * 100
    invoice_transaction.update_column(item_attribute, value)
  end

  def sum(a)
    a.inject(0){ |accum, i| accum + i }
  end

  def update_user_first_bill_paid
    return true if user.pay_first_bill
    user.update_attributes(pay_first_bill: true)
    true
  end

  def update_user_first_bill_added
    return true if user.first_bill_added || !received?
    user.update_attributes(first_bill_added: true)
    true
  end

  def clear_duplicate_alerts
    [total_alerts, alerts.duplicate_invoice].map(&:destroy_all)
  end

  def has_duplicate_alert?
    [alerts.duplicate_invoice.present?, total_alerts.duplicate_invoice.present?].any?
  end

  def alert_attributes_comparation_changed?
    [amount_due_changed?, number_changed?]
  end

  def run_alerts_clearer
    if has_duplicate_alert? && get_dupe_invoice.nil?
      clear_duplicate_alerts
    end
    true
  end

  def build_default
    return true if has_items
    line_items.build(description: 'Un accounted for line items', created_by: 0)
  end

  def create_default
    return true if by_billsync?
    return true unless vendor && vendor.default_item
    invoice_transactions.create_default_transaction(self)
  end

  def vendor_synced?
    vendor && vendor.synced_qb?
  end

  def ready_to_sync?
    return false unless user && user.synced_qb
    return false if need_information? || received? || in_process?
    return true if [deleted?, resending_payment_at?].any? && txn_id
    return false unless vendor_synced?
    return false if invoice_transactions.count == 0
    if txn_id && !invoice_transactions.pluck(:txn_line_id).all?
      update_column(:search_on_qb, true)
      return false
    end
    return false unless invoice_transactions.collect {|e| e.line_item.synced_qb? }.all?
    true
  end

  def sync_other_items
    return unless vendor
    vendor.sync_with_quickbooks_desktop! unless vendor && vendor.qb_d_id
    invoice_transactions.includes(:line_item).each do |it|
      it.line_item.save unless it.line_item.read_attribute(:expense_account_id).present?
    end
  end

  def save_tax_item
    return true unless vendor
    return true unless tax && !tax.zero?
    line_item = vendor.line_items.find_or_create_by(description: "Tax")
    invoice_transaction = invoice_transactions.where(line_item_id: line_item.id).first_or_initialize
    invoice_transaction.update_attributes(quantity: 1, price: tax, total: tax)
    true
  end

  def save_other_fees_item
    return true unless vendor
    return true unless other_fee && !other_fee.zero?
    line_item = vendor.line_items.find_or_create_by(description: "Other Fees")
    invoice_transaction = invoice_transactions.where(line_item_id: line_item.id).first_or_initialize
    invoice_transaction.update_attributes(quantity: 1, price: other_fee, total: other_fee)
    true
  end

  def set_sync_qb
    # if txn_number && bill_paid?
    #   self.sync_qb = false
    #   return true
    # end
    return true if sync_qb
    return true unless ready_to_sync?
    return self.sync_qb = true if status_changed? && [wire_sent?, archived?, deleted?].any? && ["ready_for_payment", "payment_queue", "archived"].include?(status_was) && txn_id
    return true unless [amount_due_changed?, vendor_id_changed?, due_date_changed?, number_changed?, date_changed?].any? || !txn_id.present?
    self.sync_qb = true
  end

  def sync_to_qb_desktop_payment!
    return true unless user.synced_qb
    return true unless txn_number
    update_columns(sync_qb: true, marked_as_paid: true)
  end

  def after_create_sync
    return true unless ready_to_sync?
    update_column(:sync_qb, true)
  end

  def update_intercom
    return true if Rails.env.test?
    IntercomUpdater.delayed_update user
  end

  def build_transactions
    InvoiceTransactions::AsBuilder.bulk_builder(transactions, id) if transactions.present?
  end

  def billsync_vendor
    errors.add(:vendor, "can't edit invoices from this vendor") if vendor && vendor.by_billsync?
  end

  def sync_to_accounting_system!
    if user && user.valid_xero_authentication?
      XeroSync::Invoices::Sync.find(id).sync!
    else

    end
    true
  end
end

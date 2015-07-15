class Api::V1::VendorsController < Api::V1::CoreController

  skip_before_action :authenticate_individual!, only: [:search]
  skip_load_resource only: [:search]

  skip_authorize_resource only: [:update, :search, :show]
  skip_authorization_check only: [:update, :search, :show]
  before_action :authorize_update, only: [:update]

  has_scope :only_parents
  has_scope :exclude, type: :array
  has_scope :by_vendor
  has_scope :by_period, using: [:start_date, :end_date], :type => :hash

  def index
    if params[:listing]
      respond_with collection.only_parents.order("name ASC").collect {|e| e.as_json(only: [:id, :name]) }
    elsif params[:only_parents].present?
      respond_with apply_scopes(collection).active
    else
      serializer = params[:reports_serializer] ? Api::V1::VendorReportsSerializer : Api::V1::VendorIndexSerializer
      respond_with collection.only_parents, each_serializer: serializer
    end
  end

  def show
    respond_with resource, serializer: Api::V1::VendorSerializer, include_config: params[:include_config]
  end

  def invoices
    @vendor = Vendor.find(params[:id]);
    @invoices = @vendor.invoices
    # Simply passing :serializer option won't work.  AMS expect ArraySerializer
    # for collection while we want to send an object, not array of objects.
    respond_with Api::V1::VendorSortDataSerializer.new(@invoices, default_serializer_options)
  end

  def search
    vendors = Vendor.typeahead_search(params, current_user)
    respond_with vendors, each_serializer: Api::V1::VendorTypeaheadSerializer
  end

  def unique_line_items
    @vendor = Vendor.find(params[:id]);
    @invoices = @vendor.invoices
    @line_items = Array.new
    @invoices.each do |invoice|
      @line_items.concat invoice.line_items.select(:description).to_ary()
    end
    @unique_line_items = @line_items.uniq {|l| l['description']}
    respond_with @unique_line_items
  end

  def merge
    resource.merge!(params[:children_id])
    head 200
  end

  def unmerge
    resource.unmerge!
    head 200
  end

  def destroy
    resource.inactive!
    resource.update_column(:sync_qb, true) if resource.qb_d_id
    head 200
  end

  def for_dropdown
    respond_with current_user.vendors.only_parents.where.not(name: nil).collect {|e| { id: e.id, name: e.name } }
  end

  def vendors_payments
    records = []
    ids = apply_scopes(current_user.invoices.select("DISTINCT ON(check_number) check_number, vendor_id, date, id").where.not(check_number: nil, check_date: nil)).collect(&:id)
    finds = Invoice.includes(:vendor).order("check_number DESC").find(ids)
    start_date = nil
    end_date = nil
    if params[:by_period]
      start_date = params[:by_period][:start_date]# || 14.days.ago
      end_date = params[:by_period][:end_date]# || Date.today
    end
    finds.each do |i|
      record = Api::V1::VendorPaymentReconciliatorSerializer.new(i.vendor, {check_number: i.check_number, check_date: i.check_date, start_date: start_date, end_date: end_date, by_check_date: params[:by_check_date]})
      records << record if record.bills.present?
    end

    respond_with records
  end

  def update
    if resource && resource.by_billsync?
      head 401
      return
    end
    super
  end

  private

  def authorize_update
    if vendor_params.empty?
      # Easiest way to fail authorization with nice message
      authorize! :manage, resource
    end
  end

  def end_of_association_chain
    current_user.vendors.by_user
  end

  def permitted_params
    params.permit(vendor: vendor_params)
  end

  def vendor_params
    action = params[:action].to_sym
    vendor = params.key?(:id) ? resource : Vendor
    [
      (BASIC_INFO_PARAMS if can? action, vendor),
      (PAYMENT_TERMS_PARAMS if can? :"#{action}_terms", vendor),
      ([alert_settings_attributes: ALERT_PARAMS] if can? action, vendor),
      (ACCOUNTING_PARAMS if can? :"#{action}_accounting", vendor),
      (OTHER_PARAMS if can? action, vendor),
    ].compact.flatten
  end


  BASIC_INFO_PARAMS = [
    :name, :contact_person, :email, :business_number, :fax_number,
    :cell_number, :tax_id_number, :routing_number, :bank_account_number,
    :address1, :address2, :address3, :state, :city, :zip, :created_by
  ]

  PAYMENT_TERMS_PARAMS = [
    :keep_due_date, :payment_term, :after_recieved, :day_of_the_month,
    :auto_pay_weekly, :before_due_date, :after_due_date, :payment_status,
    :payment_end_if_alert, :payment_end, :payment_end_exceed,
    :payment_end_payments, :payment_date, :payment_amount,
    :payment_amount_fixed,
  ]

  ALERT_PARAMS = begin
    delivery_ways = %i[
      text email flag
    ]
    alert_kinds = %i[
      total item itemqty itemprice duplicate_invoice marked_through
    ]
    delivery_ways.product(alert_kinds).map { |way, kind| :"alert_#{kind}_#{way}" }
  end

  ACCOUNTING_PARAMS = [
    :liability_account_id, :expense_account_id, :default_qb_class_id, :default_class_id_two
  ]

  OTHER_PARAMS = [
    # Following ones are likely to include removed attributes.
    :user_id, :default_class, :country, :after_bill_date, :end_after_payments,
    :end_autopay_over_amount, :alert_over, :auto_amount, :payment_end_date,
    :pay_day, :auto_pay_weekly_active, :parent_id
  ]

end

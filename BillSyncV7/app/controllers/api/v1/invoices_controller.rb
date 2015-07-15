class Api::V1::InvoicesController < Api::V1::CoreController
  allow_everyone only: [:show_for_turk]
  skip_authorize_resource only: [:approve, :show_for_turk]
  skip_load_resource only: [:show_for_turk]

  EVENTS = %w[mark_as_paid! mark_as_deleted! mark_with_dispute! pay_invoice! cancel_payment! ready_to_pay_to_payment_queue! pay_now!]

  has_scope :by_vendor
  has_scope :by_status, type: :array
  has_scope :by_period, using: [:start_date, :end_date], :type => :hash

  def index
    if params[:by_status].present?
      respond_with apply_scopes(collection)
      return
    end
    # Simply passing :serializer option won't work.  AMS expect ArraySerializer
    # for collection while we want to send an object, not array of objects.
    respond_with Api::V1::InvoicesIndexSerializer.new(collection, default_serializer_options)
  end

  def show_for_turk
    @hit ||= Hit.find_by!(mt_hit_id: params[:hit_id])
    @invoice ||= @hit.invoice
    respond_with @invoice, serializer: Api::V1::InvoiceTurkSerializer, hit: @hit
  end

  def update
    params.delete(:vendor_id)
    update! do |format|
      format.json { render json: resource }
    end
  end

  def aasm_events
    if aasm_event_name_param.blank?
      head :unprocessable_entity ; return
    end
    invoices = collection.find(params[:ids])
    invoices.each { |i| i.public_send aasm_event_name_param }
    render json: invoices
  end

  def counts
    respond_with collection.counts
  end

  def archived_invoices
    respond_with apply_scopes(collection.archived_invoices)
  end

  def batch_update
    invoices = Invoice.where(id: params[:invoice_ids])
    invoices.update_all(status: params[:invoice_status])
    respond_to do |format|
      format.json { render json: [], status: 200}
    end
  end

  def batch_create
    success = true
    files = params.require(:files)
    files.each do |file|
      upload = Upload.create(image: file)
      invoice = current_user.invoices.build(uploads: [upload])
      unless invoice.save(validate: false)
        success = false
      end
    end
    head(success ? :ok : :unauthorized)
  end

  # Contrary to it's name, handles invoice photo upload as well.
  def handlePdfUpload
    recreate_pdf = false;
    if(params[:invoice_id])
      recreate_pdf = true;
      invoice = Invoice.find_by_id(params[:invoice_id].to_i);
    else
      invoice = Invoice.new({:user_id => current_user.id})
    end
    upload_ids = invoice.upload_ids
    params[:files].each{ |file|
      fix_mime_type(file)
      upload = Upload.create(image: file)
      upload_ids.push(upload.id)
    }
    invoice.upload_ids = upload_ids
    invoice.pdf.clear if invoice.pdf?
    if invoice.save(validate: false)
      if(recreate_pdf)
        invoice.create_pdf
      end
      respond_with invoice, status: 200, location: nil
    else
      render_empty_json(401)
    end
  end

  def bills_count_by_status
    respond_with bills_count: collection.bills_count_by_status
  end

  def defer
    respond_to do |format|
      if resource.update_deferred_date(params[:deferred_string])
        format.json { render json: resource }
      else
        format.json { render json: resource.errors, status: 403 }
      end
    end

  end

  def approve
    unless params[:kind].in? Approval::KINDS
      head :unprocessable_entity ; return
    end
    authorize! :"#{params[:kind]}_approve", resource
    resource.approve_by current_individual, params[:kind]
    respond_to do |format|
      format.json { render json: resource.reload }
    end
  end

  def index_invoice_transactions
    respond_with resource.invoice_transactions
  end

  private

  def end_of_association_chain
    current_user.invoices
  end

  def permitted_params
    params[:invoice][:due_date] = parse_due_date if params[:due_date] || (params[:invoice] && params[:invoice][:due_date])
    params[:invoice][:resend_payment] = true if params[:resend_payment].present?
    params[:vendor_attributes][:user_id] = current_user.id if params[:vendor_attributes]
    params[:invoice][:vendor_attributes] = (params[:vendor_attributes]) if params[:vendor_attributes].present?
    params[:invoice][:upload_ids] = params[:upload_ids] if params[:upload_ids].present?
    params[:invoice][:line_items_attributes] = params[:line_items_attributes] if params[:line_items_attributes].present?
    params[:invoice][:from_user] = params[:from_user] if params[:from_user].present?
    params[:invoice][:transactions] = params[:transactions] if params[:transactions]
    params.permit(:invoice_ids, :invoice_status, :invoice_id, :pdf_file, invoice: invoice_params)
  end

  def invoice_params
    [
      :number, :image, :vendor_id, :amount_due, :tax, :other_fee, :due_date,
      :resale_number, :account_number, :delivery_address1, :delivery_address2,
      :delivery_address3, :delivery_city, :delivery_state, :delivery_zip,
      :date, :invoice_total, :new_item, :line_item_quantity, :unit_price,
      :payment_send_date, :payment_date, :from_user, :status, :resend_payment,
      :act_by, :id, :address_id, :upload_ids => [], :files => [],
      :vendor_attributes =>
        [:name, :routing_number, :bank_account_number, :address1, :address2, :city, :state, :zip, :user_id, :id],
      :transactions =>
        [:id, :total, :quantity, :code, :description, :price, :discount, :line_item_id]
    ]
  end

  def parse_due_date
    begin
      Date.strptime(params[:due_date], '%Y-%m-%d')
    rescue Exception => e
      params[:due_date]
    end
  end

  # Gecko-based browsers tend to break MIME types of uploaded files.
  def fix_mime_type uploaded_file
    correct_mime_type = MimeMagic.by_magic(File.open(uploaded_file.tempfile))
    uploaded_file.content_type = correct_mime_type
  end

  def aasm_event_name_param
    EVENTS.include?(params[:status]) && params[:status].to_sym
  end
end

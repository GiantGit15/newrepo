class Api::V1::LineItemsController < Api::V1::CoreController
  allow_everyone only: [:create, :search, :details, :batch_update, :index, :show]
  before_action :set_location_default

  def index
    respond_with resource, each_serializer: Api::V1::LineItemSerializer
  end

  def create
    invoice = Invoice.find(params[:invoice_id])
    Mturk::LineItems::Creator.create_items_with(permitted_params, invoice)
    head 200
  end

  def show
    start_date = nil
    end_date = nil
    if period = params[:by_period]
      start_date = period[:start_date]
      end_date = period[:end_date]
    end
    respond_with resource, serializer: Api::V1::LineItemReportsSerializer, serializer_params: {start_date: start_date, end_date: end_date}
  end

  def search
    respond_with LineItem.typeahead_search(params, current_user)
  end

  def batch_update
    vendor = current_user.vendors.find(params[:vendor_id])
    authorize! :manage, vendor
    line_item = vendor.line_items.find_by(description: params[:description])
    vendor.resync_invoices
    success = line_item.update_attributes(batch_update_params)
    head(success ? 200 : 403)
  end

  def update
    success = resource.update_attributes(permitted_params[:line_item])
    render json: resource, status: (success ? 200 : 403)
  end

  private

  def begin_of_association_chain
    @current_user
  end

  def permitted_params
    params.permit(:id, :mt_worker_id, :mt_hit_id, :mt_assignment_id, :description,
      :expense_account_id, :qb_class_id, :line_items => line_item_params,
      :line_item => line_item_params)
  end

  def batch_update_params
    params.permit(:expense_account_id, :qb_class_id, :qb_class_two_id)
  end

  def line_item_params
    [
      :quantity, :code, :description, :discount, :price, :total,
      :expense_account_id, :qb_class_id, :id
    ]
  end


  def set_location_default
    return unless params[:qb_class_id] && params[:qb_class_id] == 'DEFAULT_LOCATION'
    params[:qb_class_id] = nil
  end
end

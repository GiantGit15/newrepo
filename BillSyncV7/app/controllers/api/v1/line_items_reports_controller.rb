class Api::V1::LineItemsReportsController < Api::V1::CoreController
  defaults :resource_class => LineItem, :collection_name => 'line_items', :instance_name => 'line_item'
  allow_everyone only: [:index, :show, :by_vendor]

  has_scope :by_vendor
  has_scope :by_qb_class
  has_scope :by_period, using: [:start_date, :end_date], :type => :hash
  has_scope :order_by, using: [:field, :direction], :type => :hash
  # has_scope :by_vendor_name

  def index
    page = params[:page].present? ? params[:page] : 1
    per_page = params[:per_page].present? ? params[:per_page] : 100
    records = apply_scopes(current_user.line_items.reports_scopes(params[:by_vendor_name])).page(page).per(per_page)
    opts = default_serializer_options.merge(page: page, records: records, per_page: per_page)
    object = Api::V1::LineItemReportsIndexSerializer.new([], opts)
    respond_with object
  end

  def by_vendor
    vendor = Vendor.find(params[:vendor_id])
    render json: vendor.line_items.collect {|e| { id: e.id, description: e.description } }
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

  private

  def begin_of_association_chain
    @current_user
  end
end

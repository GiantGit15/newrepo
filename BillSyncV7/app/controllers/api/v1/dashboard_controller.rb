class Api::V1::DashboardController < Api::V1::CoreController
  skip_authorize_resource only: [:show]

  def show
    authorize! :read, :today
    respond_with resource
  end

  private

  def resource
    hash = { invoices: serialize_relation(invoices) }
    hash[:in_process_count] = unnescoped_invoices.where(status: [1,2]).count
    hash[:paid_last_7_days] = unnescoped_invoices.paid_last_7_days
    hash[:pending_next_7_days] = unnescoped_invoices.pending_next_7_days
    hash[:pending_next_14_days] = unnescoped_invoices.pending_next_14_days
    hash[:pending_next_month] = unnescoped_invoices.pending_next_month
    hash
  end

  def all_invoices
    current_user.invoices.by_deferred_date.includes(:vendor, :total_alerts)
  end

  def permitted_invoices
    all_invoices.accessible_by current_ability, :read
  end

  def unnescoped_invoices
    current_user.invoices
  end

  def invoices
    if params[:page]
      permitted_invoices.order("due_date ASC").where(status: [3,4]).page(params[:page]).per(50)
    else
      permitted_invoices.order("due_date ASC").where(status: [3,4])
    end
  end
  # TODO There must be a simpler way to do that
  def serialize_relation relation
    relation.collect do |e|
      Api::V1::DashboardInvoiceSerializer.new(e, default_serializer_options)
    end
  end
end

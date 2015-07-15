class Api::V1::InvoiceModerationsController < Api::V1::CoreController
  allow_everyone only: [:index, :update]

  def index
    respond_with Hit.find_mt_hit(params[:hitId])
  end

  def update
    # Remove if conditional if needed to update invoice
    return head 200 if Rails.env.development?
    proxy = InvoiceModerations::ReviewUpdaterProxy.find(params[:id])
    count = proxy.submited_count
    if proxy.update_attributes(permitted_params[:invoice_moderation])
      proxy.reload
      if count != proxy.submited_count
        head 200
      else
        head 403
      end
    else
      head 403
    end
  end

  private

  def permitted_params
    params[:invoice_moderation][:mt_worker_id] = params[:mt_worker_id] if params[:mt_worker_id].present?
    params[:invoice_moderation][:mt_assignment_id] = params[:mt_assignment_id] if params[:mt_assignment_id].present?
    params[:invoice_moderation][:mt_hit_id] = params[:mt_hit_id] if params[:mt_hit_id].present?
    params.permit(invoice_moderation: invoice_moderation_params)
  end

  def invoice_moderation_params
    [
      :id, :amount_due, :tax, :due_date, :number, :vendor_id, :account_number,
      :line_items_quantity, :mt_worker_id, :mt_assignment_id, :mt_hit_id, :date,
      :items_marked, :address1, :address2, :city, :state, :zip, :name, :other_fee,
      :routing_number, :bank_account_number, :email
    ]
  end
end

class Api::V1::InvoiceTransactionsController < Api::V1::CoreController
  allow_everyone only: [:create, :destroy]
  # skip_authorize_resource only: [:]

  def create
    builds = InvoiceTransactions::AsBuilder.bulk_builder(invoice_transaction_params[:invoice_transactions], params[:invoice_id])
    if builds.all?
      head 201
    else
      head 401
    end
  end

  def destroy
    authorize! :manage, resource.invoice
    resource.destroy
    head 201
  end

  private

  def invoice_transaction_params
    params.permit(invoice_transactions: [:description, :id,
          :line_item_id, :invoice_id, :code, :price, :quantity, :discount,
          :total, :invoice_id]
    )
  end

  def build_resource ; end

end

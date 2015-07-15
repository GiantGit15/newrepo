class Api::V1::TurkTransactionsController < Api::V1::CoreController
  allow_everyone only: [:create]

  def create
    invoice = Invoice.find(params[:invoice_id])
    if Mturk::TurkTransactions::Creator.create_items_with(permitted_params, invoice)
      head 200
    else
      head 403
    end
  end

  private

  def permitted_params
    params.permit(:id, :mt_worker_id, :mt_hit_id, :mt_assignment_id, :description,
      :expense_account_id, :qb_class_id, :turk_transactions => turk_transactions_params,
      :line_item => turk_transactions_params)
  end

  def turk_transactions_params
    [
      :quantity, :code, :description, :discount, :price, :total,
      :expense_account_id, :qb_class_id, :id
    ]
  end

end

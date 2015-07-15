class Alerts::InvoiceTransactionAlertObserver < Alerts::BaseAlertObserver

  attr_reader :invoice_transaction
  delegate :invoice, :to => :invoice_transaction
  delegate :user, :to => :invoice

  def initialize invoice_transaction
    @invoice_transaction = invoice_transaction
  end

  def watch_for_all
    new_line_item
    significant_change_in_line_items_quantity
    significant_change_in_line_item_price_unit
  end

  def new_line_item
    return if invoice_transaction.line_item.alerts.new_line_item.present?
    return unless InvoiceTransaction.where(line_item_id: invoice_transaction.line_item_id).count == 1
    return unless user.connected_to_quickbooks? || invoice.other_invoices_with_same_vendor.count >= 10
    create_alert(1, invoice_transaction)
  end

  def significant_change_in_line_items_quantity
    return unless invoice_transaction.quantity.present?
    return if invoice_transaction.alerts.line_item_quantity.present?
    invoice_transactions = invoice_transaction.last_ten_items.where.not(quantity: nil)
    calculator = calculator_for invoice_transactions, :quantity
    return unless reasonable_calculation? calculator
    create_alert(2, invoice_transaction, calculator.mean)
  end
  alias :line_item_quantity :significant_change_in_line_items_quantity

  def significant_change_in_line_item_price_unit
    return unless invoice_transaction.price.present?
    return if invoice_transaction.alerts.line_item_price_increase.present?
    invoice_transactions = invoice_transaction.last_ten_items
    calculator = calculator_for invoice_transactions, :price
    return unless reasonable_calculation? calculator
    create_alert(3, invoice_transaction, calculator.mean)
  end
  alias :line_item_price_increase :significant_change_in_line_item_price_unit

end

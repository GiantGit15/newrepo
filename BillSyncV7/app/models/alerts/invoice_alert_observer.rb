class Alerts::InvoiceAlertObserver < Alerts::BaseAlertObserver

  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def watch_for_all
    significant_increase_in_total
    new_vendor
    existing_invoice
    manual_adjustment
  end

  def significant_increase_in_total
    return if invoice.amount_due.blank?
    return if invoice.alerts.invoice_increase_total.present?
    invoices = invoice.other_invoices_with_same_vendor.last_ten
    calculator = calculator_for invoices, :amount_due
    return unless reasonable_calculation? calculator
    create_alert(0, invoice, calculator.mean)
  end
  alias :invoice_increase_total :significant_increase_in_total

  def new_vendor
    return if invoice.vendor.blank? || invoice.user.created_at.to_time >= 1.month.ago
    return if invoice.other_invoices_with_same_vendor.not_deleted.exists?
    return if invoice.total_alerts.new_vendor.present?
    return if invoice.vendor.alerts.new_vendor.present?
    create_alert(4, invoice.vendor)
  end

  def existing_invoice
    dupe = invoice.get_dupe_invoice
    return true unless dupe
    return true if invoice.total_alerts.duplicate_invoice.where(alertable_id: dupe.id, alertable_type: "Invoice").present?
    create_alert(5, dupe) if dupe.present?
  end
  alias :duplicate_invoice :existing_invoice

  def manual_adjustment
    return if invoice.total_alerts.manual_adjustment.present?
    return unless invoice.amount_due.present? && invoice.marked_thourgh_submited?
    create_alert(6, invoice)
  end

end

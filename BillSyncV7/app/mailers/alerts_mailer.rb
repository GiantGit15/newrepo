class AlertsMailer < ActionMailer::Base
  include Concerns::IntercomMessenger

  helper AnchorsHelper

  def new_alert(recipient_id, alert_id, invoice_id)
    @alert = Alert.find(alert_id.try(:to_i))
    @recipient = Individual.find(recipient_id.try(:to_i))
    @invoice = Invoice.find(invoice_id.try(:to_i))
    @vendor = @invoice.vendor

    @invoices = [@invoice]

    if @alert.duplicate_invoice?
      @invoices = [@invoice, @alert.alertable]
    else
      @invoices = [@invoice]
    end

    mail(
      to: @recipient.email,
      subject: @alert.sms_text
    )
  end
end

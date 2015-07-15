class Notifier < ActionMailer::Base
  include Concerns::IntercomMessenger

  def user_not_found(email)
    @sender = email
    mail(
      to:       email,
      subject:  "Your email was not found on our database"
    )
  end

  def mail_without_attachment(email)
    @sender = email
    mail(
      to:       email,
      subject:  "Your email doesn't contain any invoice"
    )
  end

  def notify_invoices_received(invoices, email)
    mail(
      to:       email,
      subject:  "We received your bills and are processsing it."
    )
  end

  def bill_processed(invoice)
    @invoice = invoice

    mail(
      to:       invoice.source_email,
      subject:  "We received your bills and are processsing it."
    )
  end

  def xero_timeout(user)
    emails = user.email_notifications
    mail(
      to: emails,
      subject: "[billSync] Xero -> #{user.business_name} connection expired",
      body: "Wanted to give you a quick heads up that your connection to Xero and #{user.business_name} has expired.  To reconnect please go to the settings screen to reconnect. This is required periodically by the team at Xero sorry for the inconvenience."
    )
  end

  def intuit_disconnection(user)
    mail(
      to: user.email_notifications,
      subject: "[billSync] QuickBooks connection stopped",
      body: "Your connection with QuickBooks has been disconnected at your request"
    )
  end
end

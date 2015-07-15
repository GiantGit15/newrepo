# == Schema Information
#
# Table name: alerts
#
#  id               :integer          not null, primary key
#  created_at       :datetime
#  updated_at       :datetime
#  alertable_id     :integer
#  category         :integer
#  invoice_owner_id :integer
#  alertable_type   :string(255)
#  short_text       :text
#  large_text       :text
#  average          :decimal(, )
#  sms_text         :text
#

class Alerts::AlertCreator < Alert
  before_save :parse_average
  before_save :set_texts

  after_create :notify_users!
  after_create :cancel_payment_if_alert_active
  after_create :log_creation

  def set_texts
    self.public_send :"set_texts_for_#{category}"
  end

  def set_texts_for_invoice_increase_total
    text = alertable.amount_due > average ? "higher" : "lower"
    vendor_name = obtain_vendor_name(alertable.vendor)
    amount = "%.2f" % alertable.amount_due rescue nil
    self.short_text = "#{text.capitalize} than normal bill"
    self.large_text = "This bill from #{vendor_name} is signicantly #{text}. The total on this bill is #{amount}, while you average bill is #{average}.You may want to look over the bill."
    self.sms_text = "This bill from #{vendor_name} is signicantly #{text}. The total on this bill is #{amount}, while you average bill is #{average}.You may want to look over the bill."
  end

  def set_texts_for_new_line_item
    vendor_name = obtain_vendor_name(alertable.invoice.vendor)
    amount = "%.2f" % alertable.price rescue nil
    self.short_text = "New Line Item"
    self.large_text = "We noticed a new line item on this invoice, #{alertable.description} at a unit price of $#{amount}"
    self.sms_text = "We noticed a new line item from #{vendor_name}, #{alertable.description} at a unit price of $#{amount}"
  end

  def set_texts_for_line_item_quantity
    vendor_name = obtain_vendor_name(alertable.line_item.vendor)
    self.short_text = "Large change in order volume"
    self.large_text = "We noticed this bills order #{alertable.description} in your past 10 orders you have averaged #{average} of the same item"
    self.sms_text = "We noticed  #{vendor_name} delivery of #{alertable.description} in your past 10 orders you have averaged #{average} of the same item"
  end

  def set_texts_for_line_item_price_increase
    text = alertable.price > average ? "higher" : "lower"
    vendor_name = obtain_vendor_name(alertable.line_item.vendor)
    amount = "%.2f" % alertable.price rescue nil
    self.short_text = "We noticed a large change in price"
    self.large_text = "We noticed this bill's price for #{alertable.description} at $#{amount} is significantly #{text} than the normal price of $#{average}."
    self.sms_text = "We noticed #{vendor_name}'s price for #{alertable.description} at $#{amount} is significantly #{text} than the normal price of $#{average}."
  end

  def set_texts_for_new_vendor
    vendor_name = obtain_vendor_name(alertable)
    self.short_text = "New vendor"
    self.large_text = "We've never seen #{vendor_name} for you before, wanted to highlight it was new to us!"
    self.sms_text = "We've never seen #{vendor_name} for you before, wanted to highlight it was new to us!"
  end

  def set_texts_for_duplicate_invoice
    vendor_name = obtain_vendor_name(alertable.vendor)
    self.short_text = "This maybe a duplicate bill"
    self.large_text = "This looks like a duplicate bill from this vendor. The bill number or the date and total value seem to match the bill linked to below. Click here to see the other invoice"
    self.sms_text = "A bill from  #{vendor_name} looks like a duplicate bill.  Please login to your account to check it."
  end

  def set_texts_for_manual_adjustment
    vendor_name = obtain_vendor_name(alertable.vendor)
    self.short_text = "Manual adjustments"
    self.large_text = "Bill was manually adjusted/had extra markings so we re-calculated the amount due please check it"
    self.sms_text = "A bill from #{vendor_name} was manually adjusted so we re-calculated the amount due"
  end

  def set_texts_for_no_location
    self.short_text = "Unable to find a location/class for the bill"
    self.large_text = "Unable to find a location/class for the bill"
    self.sms_text = "Unable to find a location/class for the bill"
  end

  def set_texts_for_processing_items
    self.short_text = "Line items still processing"
    self.large_text = "We are still working on the line items for this bill"
    self.sms_text = "Line items still processing"
  end

  private

  def notify_users!
    AlertsNotifier.new(self, invoice_owner).notify!
  end

  def cancel_payment_if_alert_active
    return true unless invoice_owner.vendor
    return true unless invoice_owner.vendor.payment_end_if_alert && invoice_owner.payment_queue?
    invoice_owner.cancel_payment!
    true
  end

  def obtain_vendor_name vendor
    vendor.try(:name).presence || "(unnamed)"
  end

  def log_creation
    Rails.logger.info "Alert created: #{category}: #{short_text}."
  end

  def parse_average
    self.average = "%.2f" % average rescue average
  end
end

# == Schema Information
#
# Table name: common_alert_settings
#
#  id                            :integer          not null, primary key
#  email_new_invoice_onchange    :boolean          default(FALSE)
#  email_new_invoice_daily       :boolean          default(FALSE)
#  email_new_invoice_weekly      :boolean          default(TRUE)
#  email_new_invoice_none        :boolean          default(FALSE)
#  email_change_invoice_onchange :boolean          default(FALSE)
#  email_change_invoice_daily    :boolean          default(FALSE)
#  email_change_invoice_weekly   :boolean          default(TRUE)
#  email_change_invoice_none     :boolean          default(FALSE)
#  email_paid_invoice_onchange   :boolean          default(FALSE)
#  email_paid_invoice_daily      :boolean          default(FALSE)
#  email_paid_invoice_weekly     :boolean          default(TRUE)
#  email_paid_invoice_none       :boolean          default(FALSE)
#  email_savings_onchange        :boolean          default(FALSE)
#  email_savings_daily           :boolean          default(FALSE)
#  email_savings_invoice_weekly  :boolean          default(TRUE)
#  email_savings_invoice_none    :boolean          default(FALSE)
#  text_new_invoice_onchange     :boolean          default(FALSE)
#  text_new_invoice_daily        :boolean          default(FALSE)
#  text_new_invoice_weekly       :boolean          default(FALSE)
#  text_new_invoice_none         :boolean          default(TRUE)
#  text_change_invoice_onchange  :boolean          default(FALSE)
#  text_change_invoice_daily     :boolean          default(FALSE)
#  text_change_invoice_weekly    :boolean          default(FALSE)
#  text_change_invoice_none      :boolean          default(TRUE)
#  text_paid_invoice_onchange    :boolean          default(FALSE)
#  text_paid_invoice_daily       :boolean          default(FALSE)
#  text_paid_invoice_weekly      :boolean          default(FALSE)
#  text_paid_invoice_none        :boolean          default(TRUE)
#  text_savings_onchange         :boolean          default(FALSE)
#  text_savings_daily            :boolean          default(FALSE)
#  text_savings_invoice_weekly   :boolean          default(FALSE)
#  text_savings_invoice_none     :boolean          default(TRUE)
#  created_at                    :datetime
#  updated_at                    :datetime
#  individual_id                 :integer
#

class CommonAlertSettings < ActiveRecord::Base
  belongs_to :individual, inverse_of: :common_alert_settings

  TOGGLE_RX = /\A(email|text)_.*_(onchange|daily|weekly|none)\Z/
  TOGGLES = attribute_names.grep TOGGLE_RX
end

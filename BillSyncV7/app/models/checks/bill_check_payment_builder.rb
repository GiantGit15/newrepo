# == Schema Information
#
# Table name: checks
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  sent_date     :date
#  number        :string(255)
#  vendor_id     :integer
#  txn_id        :string(255)
#  time_created  :datetime
#  time_modified :datetime
#  edit_sequence :string(255)
#  txn_number    :string(255)
#  sync_qb       :boolean          default(FALSE)
#  created_at    :datetime
#  updated_at    :datetime
#

class Checks::BillCheckPaymentBuilder < Check

  def to_xml!
    edit = txn_id? && txn_number? && edit_sequence?
    sync_type = edit ? :bill_payment_check_mod : :bill_payment_check_add
    {
      "#{sync_type}_rq" => {
        xml_attributes: { "requestID" => id },
        sync_type => edit ? modification_payment_attributes : add_payment_attributes
      }
    }
  end

  def add_payment_attributes
    hash = { payee_entity_ref: { "ListID" => vendor.qb_d_id } }
    hash["APAccountRef"] = { "ListID" => vendor.default_liability_account.qb_d_id } if vendor && vendor.default_liability_account && vendor.default_liability_account.qb_d_id
    hash[:txn_date] = sent_date
    hash[:bank_account_ref] = { list_id: user.bank_account.qb_d_id }
    hash[:ref_number] = number
    hash[:applied_to_txn_add] =  bill_transactions
    hash
  end

  def modification_payment_attributes
    {
      txn_id: bill_payment_txn_id,
      edit_sequence: edit_sequence,
      "APAccountRef" => { "ListID" => vendor.default_liability_account.qb_d_id },
      txn_date: sent_date,
      bank_account_ref: { list_id: user.bank_account.qb_d_id },
      ref_number: user.check_number,
      applied_to_txn_mod: bill_transactions
    }
  end

  def bill_transactions
    @bill_transactions ||= invoices.order("created_at ASC").where.not(txn_id: "81-1433457175").collect(&:to_bill_payment_check_attribute)
  end

  def testing
    bill_transactions.last
  end

end

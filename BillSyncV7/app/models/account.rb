# == Schema Information
#
# Table name: accounts
#
#  id               :integer          not null, primary key
#  qb_id            :integer
#  sync_token       :integer
#  name             :string(255)
#  user_id          :integer
#  parent_id        :integer
#  sub_account      :boolean          default(FALSE)
#  account_type     :string(255)
#  account_sub_type :string(255)
#  classification   :string(255)
#  status           :integer          default(0)
#  created_at       :datetime
#  updated_at       :datetime
#  qb_d_id          :string(255)
#  sync_qb          :boolean          default(FALSE)
#  edit_sequence    :string(255)
#  search_on_qb     :boolean          default(FALSE)
#  parent_ref       :string(255)
#  request_number   :integer          default(0)
#  xero_id          :string(255)
#  xero_code        :string(255)
#  description      :text
#

class Account < ActiveRecord::Base

  belongs_to :user
  has_one :user_expense, class_name: "User", inverse_of: :expense_account
  has_one :user_liability, class_name: "User", inverse_of: :liability_account
  has_one :user_bank, class_name: "User", inverse_of: :bank_account

  has_one :vendor_expense, class_name: "Vendor", inverse_of: :expense_account
  has_one :vendor_liability, class_name: "Vendor", inverse_of: :liability_account

  has_one :line_item_expense, class_name: "LineItem", inverse_of: :expense_account
  has_one :line_item_liability, class_name: "LineItem", inverse_of: :liability_account

  belongs_to :parent, class_name: "Account", inverse_of: :childrens
  has_many :childrens, class_name: "Account", inverse_of: :parent

  enum status: [:active, :inactive]

  before_save :try_to_sync_bills

  def account_ref
    account = Quickbooks::Model::BaseReference.new
    account.name = name
    account.value = qb_id
    account
  end

  def query_qb_desktop
    query = { xml_attributes: { "requestID" => id } }
    if qb_d_id
      query["ListID"] = qb_d_id
    else
      query[:full_name] = name
    end
    {
      account_query_rq: query
    }
  end

  def to_qb_xml
    sync_type =  :account_add
    outher_wrapper = "#{sync_type}_rq".to_sym
    inner_wrapper = "#{sync_type}".to_sym
    hash = {
      outher_wrapper => {
        xml_attributes: { "requestID" => id },
         inner_wrapper => inner_attributes
      }
    }
  end

  def sync_qb_desktop!
    search_on_qb ? query_qb_desktop : to_qb_xml
  end

  def synced_qb?
    edit_sequence && qb_d_id
  end

  def try_to_sync_bills
    user.vendors.joins(:line_items).where("line_items.expense_account_id = ? OR vendors.expense_account_id = ?", id, id).uniq.each do |invoice|
      invoice.resync_invoices
    end
    true
  end

  private

  def inner_attributes
    hash = {}
    hash[:list_id] = qb_d_id if qb_d_id
    hash[:edit_sequence] = edit_sequence if edit_sequence
    hash.merge!({
      name: name.truncate(31),
      is_active: true
    })

    # hash[:parent_ref] = { list_id: parent_ref } if parent_ref
    hash[:account_type] = get_account_type

    hash
  end

  def get_account_type
    user.intuit_authentication? ? qbo_account_type : qbd_account_type
  end

  def qbd_account_type
    [
      "Accounts Receivable", "Cost Of Goods Sold", "Credit Card", "Fixed Asset",
      "Long Term Liability", "Non Posting", "Other Asset", "Other Current Asset",
      "Other Current Liability", "Other Expense", "Other Income"
    ].map(&:downcase).include?(account_type.downcase) ? account_type.titleize.split.join : account_type
  end

  def qbo_account_type
    [
      "AccountsPayable", "AccountsReceivable", "CostOfGoodsSold", "CreditCard",
      "FixedAsset", "LongTermLiability", "NonPosting", "OtherAsset",
      "OtherCurrentAsset", "OtherCurrentLiability", "OtherExpense"
    ].map(&:downcase).include?(account_type.downcase) ? account_type.titleize : account_type
  end

end

# == Schema Information
#
# Table name: authentications
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  provider      :string(255)
#  uid           :string(255)
#  name          :string(255)
#  token         :string(255)
#  secret        :string(255)
#  support_field :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  merchant_id   :string(255)
#  client_id     :string(255)
#  phone         :string(255)
#

class Authentication < ActiveRecord::Base
  belongs_to :user
  belongs_to :individual

  PROVIDERS = { intuit: "intuit", xero: "xero" }

  scope :for_open_id, ->(opts) { joins(:individual).where("individuals.email = ? AND uid = ?", opts[:email], opts[:uid]) }

  def self.create_intuit_authentication(auth)
    opts = { provider: PROVIDERS[:intuit], uid: auth["uid"] }
    where(opts).first_or_create
  end

  def save_renewed_token(result)
    update_attributes(token: result.token, secret: result.secret)
  end

  def valid_intuit_auth?
    persisted? && [token, secret].all?(&:present?)
  end
end

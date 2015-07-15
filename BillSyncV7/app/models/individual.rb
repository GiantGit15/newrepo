# == Schema Information
#
# Table name: individuals
#
#  id                       :integer          not null, primary key
#  user_id                  :integer
#  email                    :string(255)      default(""), not null
#  encrypted_password       :string(255)      default(""), not null
#  reset_password_token     :string(255)
#  reset_password_sent_at   :datetime
#  sign_in_count            :integer          default(0), not null
#  current_sign_in_at       :datetime
#  last_sign_in_at          :datetime
#  current_sign_in_ip       :string(255)
#  last_sign_in_ip          :string(255)
#  confirmation_token       :string(255)
#  confirmed_at             :datetime
#  confirmation_sent_at     :datetime
#  unconfirmed_email        :string(255)
#  failed_attempts          :integer          default(0), not null
#  unlock_token             :string(255)
#  locked_at                :datetime
#  created_at               :datetime
#  updated_at               :datetime
#  name                     :string(255)      default("User"), not null
#  limit_min                :decimal(, )
#  limit_max                :decimal(, )
#  terms_of_service         :boolean          default(TRUE)
#  last_selected_company_id :integer
#  invited_by               :integer
#  status                   :integer          default(0)
#

class Individual < ActiveRecord::Base
  attr_accessor :mobile_phone, :business_name, :password_to_be_delivered, :inviter_name
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :trackable, :validatable, :lockable, :timeoutable,
         :confirmable, :omniauthable, :omniauth_providers => [:intuit]

  # belongs_to :inviter, class_name: "Individual", inverse_of: :invitees
  # has_many :invitees, class_name: "Individual", inverse_of: :inviter, foreign_key: :invited_by
  has_many :appointments
  has_many :users, through: :appointments
  has_many :roles, through: :appointments
  has_many :authentications

  belongs_to  :last_selected_company, class_name: 'User', foreign_key: 'last_selected_company_id'

  has_one :number, inverse_of: :individual

  has_many :approvals, inverse_of: :approver
  has_and_belongs_to_many :permitted_expense_accounts, class_name: "Account", join_table: "individuals_permitted_accounts" # active admin error
  has_and_belongs_to_many :permitted_qb_classes, class_name: "QBClass", join_table: "individuals_permitted_qb_classes"
  has_and_belongs_to_many :permitted_vendors, class_name: "Vendor", join_table: "individuals_permitted_vendors"
  has_one :common_alert_settings, inverse_of: :individual, autosave: true
  has_many :vendor_alert_settings, class_name: "VendorAlertSettings", inverse_of: :individual

  after_initialize :build_common_alert_settings, :if => proc { |o| o.common_alert_settings.nil? }

  before_create :associate_last_selected_company
  after_create :create_intercom_resource
  after_save :associate_new_number

  after_save :update_intercom
  after_save :deliver_new_password

  validate :mobile_phone_validity

  accepts_nested_attributes_for :number

  enum status: [:visible, :hidden]

  def permission_scopes
    permitted_expense_accounts + permitted_qb_classes + permitted_vendors
  end

  def registration_link
    return if confirmed?
    Rails.application.routes.url_helpers.individual_confirmation_url(self, confirmation_token: confirmation_token)
  end

  # Assigns random password to user and returns that password.
  def randomize_password
    new_password = Devise.friendly_token.first(8)
    self.password_to_be_delivered = self.password = self.password_confirmation = new_password
  end

  def current_permissions
    appointments.where(user_id: last_selected_company_id).first.permissions
  end

  private

  def mobile_phone_validity
    return unless mobile_phone.present?
    server_number
  end

  def server_number
    errors.add(:mobile_phone, "this number is not available") if Number::RESTRICTED_NUMBERS.include?(mobile_phone)
  end

  def associate_new_number
    return true unless mobile_phone.present?
    if number.present?
      number.update_attributes(string: mobile_phone)
    else
      create_number(string: mobile_phone)
    end
  end

  def update_intercom
    IntercomUpdater.delayed_update self
  end

  def create_intercom_resource
    IntercomUpdater.update self
  end

  def deliver_new_password
    if password_to_be_delivered.present?
      send_devise_notification(:individual_created, password_to_be_delivered)
      password_to_be_delivered = nil
    end
  end

  def associate_last_selected_company
    return true unless users.present?
    self.last_selected_company = users.first
    true
  end
end

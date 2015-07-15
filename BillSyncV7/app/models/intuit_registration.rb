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

class IntuitRegistration < Individual
  USER_ATTRIBUTES = %w[timezone business_name mobile_phone]

  delegate *USER_ATTRIBUTES.flat_map{ |a| [a, "#{a}="] }, :to => :user

  validates :name, :business_name, :mobile_phone, :email, :timezone, presence: true
  validates :terms_of_service, acceptance: { accept: true }

  before_save :associate_last_selected_company
  before_save :set_number

  # after_initialize is triggered too late
  def user
    @user ||= users.first || users.build
  end

  def validate_number
    number.valid? or errors[:mobile_phone].concat number.errors[:string]
  end

  def associate_last_selected_company
    self.last_selected_company = user
  end

  def set_number
    user.mobile_phone = mobile_phone
    user.save
  end
end

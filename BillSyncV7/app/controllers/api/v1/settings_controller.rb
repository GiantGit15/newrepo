# It is more general than UsersController and is replacing it for all
# actions related with updating profile attributes.  It is able to
# distinguish user's and individual's properties and handle them
# accordingly.  It is also able to render current individual.
class Api::V1::SettingsController < Api::V1::CoreController
  skip_load_and_authorize_resource
  skip_authorization_check only: [:update, :show, :verify_bank_information]

  def update
    ActiveRecord::Base.transaction do
      current_individual.common_alert_settings.attributes = permitted_alert_settings_params
      current_individual.attributes = permitted_individual_params
      current_individual.save!
      current_user.update! permitted_user_params
    end
    current_individual.reload
    render_current_individual
  end

  def show
    render_current_individual
  end

  def update_password
    authorize! :update_password, :himself

    if current_individual.update_with_password(permitted_update_password_params)
      sign_in current_individual, :bypass => true
      render_current_individual status: :ok
    else
      respond_to do |format|
        format.json { render json: current_individual.errors, status: 401 }
      end
    end
  end

  def verify_bank_information
    authorize! :verify, current_user

    if current_user.verify_bank_information(params[:verification])
      head 200
    else
      head 403
    end
  end

  def disconnect
    authorize! :update, User
    if current_user
      current_user.disconnect_from_quickbooks!
      respond_to do |format|
        format.json { render json: {}, status: 200 }
        format.html { redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/profiles/accounting?disconnected=true"}
      end
    else
      head 403
    end
  end

  def disconnect_from_xero
    authorize! :update, User
    if current_user
      current_user.disconnect_from_xero!
      render json: {}, status: 200
    else
      head 403
    end
  end

  private

  def render_current_individual options = {}
    options.reverse_merge!(
      json: current_individual,
      serializer: Api::V1::CurrentIndividualSerializer,
      location: api_v1_settings_url
    )
    render options
  end

  def permitted_user_params
    params.require(:individual).require(:user).permit [
      :id, :invite_code, :name, :mobile_phone, :business_name, :email,
      :billing_address1, :billing_address2, :billing_city, :billing_state,
      :billing_zip, :business_type, :routing_number, :bank_account_number,
      :mobile_number, :check_number, :expense_account_id, :liability_account_id,
      :bank_account_id, :terms_of_service, :sms_time, :pay_bills_through_text,
      :locations_feature, :modal_used, :default_class_id, :default_due_date,
      :timezone, :alert_marked_through, :file_password, :signature, :doing_business_as,
      :default_class_id_two, :emails_attributes => [:id, :string],
      :clover_authentication => [:merchant_id, :phone, :client_id, :token]
    ]
  end

  def permitted_individual_params
    params.require(:individual).permit [
      :name, :email,
      :number_attributes => [:id, :string]
    ]
  end

  def permitted_alert_settings_params
    params.require(:individual).permit CommonAlertSettings::TOGGLES
  end

  def permitted_update_password_params
     params.permit([:password, :password_confirmation, :current_password])
  end
end

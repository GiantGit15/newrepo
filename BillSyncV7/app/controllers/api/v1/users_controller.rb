class Api::V1::UsersController < Api::V1::CoreController
  before_action :authenticate_individual!, except: [:authenticate, :oauth_callback, :company_info]
  before_action :set_resource, only: [:update]
  allow_everyone only: [:authenticate, :oauth_callback]
  skip_authorization_check only: [:show, :company_info, :authenticate, :oauth_callback, :update]
  skip_load_and_authorize_resource only: [:show, :company_info, :authenticate, :oauth_callback, :update]

  def authenticate
    callback = oauth_callback_api_v1_users_url
    token = $qb_oauth_consumer.get_request_token(:oauth_callback => callback)
    session[:qb_request_token] = Marshal.dump(token)
    redirect_to("https://appcenter.intuit.com/Connect/Begin?oauth_token=#{token.token}") and return
  end

  def oauth_callback
    at = Marshal.load(session[:qb_request_token]).get_access_token(:oauth_verifier => params[:oauth_verifier])
    session.delete(:qb_request_token)
    oauth_client = OAuth::AccessToken.new($qb_oauth_consumer, at.token, at.secret)
    company_service = Quickbooks::Service::CompanyInfo.new
    company_service.access_token = oauth_client
    company_service.company_id = params['realmId']
    response = company_service.query
    response = response.first
    user = current_individual.last_selected_company || User.new(individuals: [current_individual])
    user.save_qbo_settings(at, params['realmId'], response, current_individual)
    user.start_qb_o_syncs

    if user.
            d_at > 2.minutes.ago
      redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/registration/new"
    elsif session[:redirection_url].present?
      session[:redirection_url] = nil
      redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/profiles/accounting"
    else
      respond_to do |format|
        puts "here"
        format.html { render 'api/v1/users/oauth_callback' }
        format.json do              # render an html page instead of a JSON response
          render 'api/v1/users/oauth_callback.html', {
            :content_type => 'text/html',
            :layout       => 'application'
          }
        end
      end
    end
  end

  def company_info
    begin
      user = Hit.find_by(mt_hit_id: params[:hit_id]).invoice.user
      addresses = user.addresses.collect {|e| {name: e.name.try(:downcase), address1: e.address1.try(:downcase) } }
      user_company = { name: user.business_name.try(:downcase), address1: user.billing_address1.try(:downcase), user_mark: true }
      user_doing_business_as = { name: user.doing_business_as.try(:downcase), address1: nil, user_mark: true }
      render json: [user_company, user_doing_business_as, addresses ].flatten
    rescue => e
      puts e.message
      head 404
    end
  end

  def set_user_in_session
    session[:user_id] = params[:user_id]
  end

  def update
    head(current_user.update_attributes(permitted_params) ? 200 : 403)
  end

  private

  def permitted_params
    params.permit(user: user_params)
  end

  def user_params
    [
      :id, :invite_code, :name, :mobile_phone, :business_name, :email,
      :billing_address1, :billing_address2, :billing_city, :billing_state,
      :billing_zip, :business_type, :routing_number, :bank_account_number,
      :mobile_number, :check_number, :expense_account_id, :liability_account_id,
      :bank_account_id, :terms_of_service, :sms_time, :pay_bills_through_text,
      :locations_feature, :modal_used, :default_class_id, :default_due_date,
      :timezone, :alert_marked_through, :file_password, :default_class_id_two,
      :emails_attributes => [:id, :string]
    ]
 end

  def set_resource
   @user = current_user
  end
end

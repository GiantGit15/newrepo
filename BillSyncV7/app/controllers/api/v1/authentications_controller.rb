class Api::V1::AuthenticationsController < Api::V1::CoreController
  skip_before_action :authenticate_individual!, only: [:destroy]

  allow_everyone only: [:from_intuit, :to_intuit, :destroy, :launch_from_intuit]

  def destroy
    find_individual_and_sign_in if params[:realmId] && !current_individual
    authorize! :update, User
    if current_user && current_user.disconnet_from(params)
      respond_to do |format|
        format.json { redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/profiles/accounting?disconnected=true" }
        format.html { redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/profiles/accounting?disconnected=true"}
      end
    else
      head 403
    end
  end

  def from_intuit
    at = Marshal.load(session[:qb_request_token]).get_access_token(:oauth_verifier => params[:oauth_verifier])
    session.delete(:qb_request_token)
    oauth_client = OAuth::AccessToken.new($qb_oauth_consumer, at.token, at.secret)
    company_service = Quickbooks::Service::CompanyInfo.new
    company_service.access_token = oauth_client
    company_service.company_id = params['realmId']
    response = company_service.query
    response = response.first
    notify_with_airbrake(req, params, {qbo_response: response.to_json})
  end

  def to_intuit
    callback = oauth_callback_api_v1_users_url
    token = $qb_oauth_consumer.get_request_token(:oauth_callback => callback)
    session[:qb_request_token] = Marshal.dump(token)
    redirect_to("https://appcenter.intuit.com/Connect/Begin?oauth_token=#{token.token}") and return
  end

  def launch_from_intuit
    find_individual_and_sign_in
    redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/dashboard"
  end

  private

  def notify_with_airbrake(request, response, options = {})
    basdas
  rescue NameError => error
    Airbrake.notify_or_ignore(error,
      parameters: {request: request.to_json, response: response.to_json, options: options},
      error_class: "FOR INTUIT TESTING",
      error_message: "TESTING"
     )
  end

  def find_individual_and_sign_in
    if individual = Authentication.find_by(realm_id: params[:realmId]).try(:individual)
      sign_in individual, :event => :authentication
    end
  end
end

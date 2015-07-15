class Api::V1::Auth::XeroSessionsController < Api::V1::CoreController
  skip_authorization_check only: [:new, :create, :destroy]
  skip_load_and_authorize_resource only: [:new, :create, :destroy]
  before_filter :get_xero_client

  def new
    request_token = @xero_client.request_token(:oauth_callback => api_v1_create_xero_session_url)
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret

    redirect_to request_token.authorize_url
  end

  def create
    @xero_client.authorize_from_request(
      session[:request_token],
      session[:request_secret],
      :oauth_verifier => params[:oauth_verifier]
    )

    current_user.start_xero_sync(@xero_client.access_token.token, @xero_client.access_token.secret)

    session[:request_token] = nil
    session[:request_secret] = nil
    redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/profiles/accounting"
  end

  def destroy
    session.data.delete(:xero_auth)
  end

  private

  def get_xero_client
    @xero_client = Xeroizer::PublicApplication.new(ENV["XERO_CONSUMER_KEY"], ENV["XERO_CONSUMER_SECRET"])

    # Add AccessToken if authorised previously.
    if session[:xero_auth]
      @xero_client.authorize_from_access(
        session[:xero_auth][:access_token], session[:xero_auth][:access_key]
      )
    end
  end
end

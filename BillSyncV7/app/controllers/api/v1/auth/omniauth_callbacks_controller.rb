class Api::V1::Auth::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_filter :verify_authenticity_token, :only => [:intuit]

  def intuit
    individual = User.find_individual_for_open_id(request.env["omniauth.auth"], current_individual) # returns individual
    if !current_individual
      sign_in individual, :event => :authentication
    elsif current_individual != individual
      sign_out current_individual
      sign_in individual, :event => :authentication
    end
    session[:redirection_url] = authenticate_api_v1_users_path
    redirect_to authenticate_api_v1_users_path
  end

  private

  def redirect_to_dashboard(email)
    redirect_to "#{ENV["ROOT_REDIRECTION_URL"]}#/dashboard?email=#{email}"
  end
end

class ApplicationController < ActionController::Base
 before_action :configure_permitted_parameters, if: :devise_controller?


  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
#  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

#   respond_to :html, :json

#   after_filter  :set_csrf_cookie_for_ng

#   include ActionController::MimeResponds

#   def set_csrf_cookie_for_ng
#     cookies['XSRF-TOKEN'] = form_authenticity_token if protect_against_forgery?
#   end

#   def render_with_protection(json_content, parameters = {})
#     render parameters.merge(content_type: 'application/json', text: ")]}',\n" + json_content)
#   end

protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) << :name
    devise_parameter_sanitizer.for(:sign_up) << :invite_code
    devise_parameter_sanitizer.for(:sign_up) << :mobile_phone
    devise_parameter_sanitizer.for(:sign_up) << :business_name
    devise_parameter_sanitizer.for(:sign_up) << :business_type
    devise_parameter_sanitizer.for(:sign_up) << :routing_number
    devise_parameter_sanitizer.for(:sign_up) << :bank_account_number
    devise_parameter_sanitizer.for(:sign_up) << :timezone
    devise_parameter_sanitizer.for(:sign_up) << :default_due_date
    devise_parameter_sanitizer.for(:sign_up) << :terms_of_service
    devise_parameter_sanitizer.for(:account_update) << :name
    devise_parameter_sanitizer.for(:account_update) << :invite_code
    devise_parameter_sanitizer.for(:account_update) << :mobile_phone
    devise_parameter_sanitizer.for(:account_update) << :business_name
    devise_parameter_sanitizer.for(:account_update) << :business_type
    devise_parameter_sanitizer.for(:account_update) << :routing_number
    devise_parameter_sanitizer.for(:account_update) << :bank_account_number
    devise_parameter_sanitizer.for(:account_update) << :default_due_date
  end

#     def intercept_html_requests
#       redirect_to('/') if request.format == Mime::HTML
#     end

#   def verified_request?
#     super || form_authenticity_token == request.headers['X_XSRF_TOKEN']
#   end
end

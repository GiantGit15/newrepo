class Api::V1::Auth::SessionsController < Devise::SessionsController
  include ::Concerns::DeviseRedirectionPaths

  before_action :set_security_headers

  # Copied from original Devise.  Overriding and using super keyword is not
  # enough as it does not allow response customization.
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message(:notice, :signed_in) if is_flashing_format?
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: to_location(resource), serializer: Api::V1::CurrentIndividualSerializer, root: false
  end

  def to_location(resource)
    if session[:redirection_url].present?
      session[:redirection_url]
    else
      after_sign_in_path_for(resource)
    end
  end

  protected

  def set_security_headers
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end
end

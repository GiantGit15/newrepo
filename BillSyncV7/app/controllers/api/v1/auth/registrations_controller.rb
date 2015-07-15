class Api::V1::Auth::RegistrationsController < Devise::RegistrationsController
  include ::Concerns::DeviseRedirectionPaths

  def create
    build_resource(sign_up_params)

    resource.save
    yield resource if block_given?
    if resource.persisted?
      if resource.active_for_authentication?
        set_flash_message :notice, :signed_up if is_flashing_format?
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource), serializer: Api::V1::CurrentIndividualSerializer, root: false
      else
        set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_flashing_format?
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource), serializer: Api::V1::CurrentIndividualSerializer, root: false
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  def build_resource sign_up_params
    klass = params[:individual] && params[:individual][:intuit] ? IntuitRegistration : Registration
    self.resource = klass.send(:find_or_initialize_by, {email: sign_up_params[:email]})
    resource.attributes = sign_up_params
    resource
  end

end

module Concerns
  module DeviseRedirectionPaths
    include ActiveSupport::Concern

    DEVISE_REDIRECTION_ROUTE = ENV['DEVISE_REDIRECTION_ROUTE']

    PATH_METHODS = %i[
      after_resending_confirmation_instructions_path_for
      after_sign_in_path_for
      after_sign_out_path_for
      after_sign_up_path_for
      after_sending_reset_password_instructions_path_for
    ]

    PATH_METHODS.each do |method_name|
      define_method(method_name) { |*_| DEVISE_REDIRECTION_ROUTE || app_url }
    end

    def after_confirmation_path_for(resource, options)
      "#{app_url}#/registration/confirmed"
    end
  end
end

class Api::V1::Auth::PasswordsController < Devise::PasswordsController
  include ::Concerns::DeviseRedirectionPaths
  respond_to :json
end

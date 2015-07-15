class Api::V1::Auth::ConfirmationsController < Devise::ConfirmationsController
  include ::Concerns::DeviseRedirectionPaths
end

class Api::V1::EmailsController < Api::V1::CoreController

  private
  def permitted_params
    params.permit(email: [:id, :string])
  end

  def end_of_association_chain
    current_user.emails
  end
end

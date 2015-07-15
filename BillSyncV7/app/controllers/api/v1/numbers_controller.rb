class Api::V1::NumbersController < Api::V1::CoreController

  private
  def permitted_params
    params.permit(number: [:id, :string])
  end

  def end_of_association_chain
    current_user.numbers
  end
end

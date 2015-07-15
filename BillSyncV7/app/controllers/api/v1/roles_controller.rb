class Api::V1::RolesController < Api::V1::CoreController

  def index
    # Include stock roles in this action only
    relation = Role.where(user_id: [current_user.id, nil])
    respond_with relation
  end

  private

  def permitted_params
    params.permit(role: [:name, {:permissions => []}])
  end

  def end_of_association_chain
    current_user.roles
  end
end

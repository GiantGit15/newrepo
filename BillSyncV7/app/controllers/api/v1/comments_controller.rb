class Api::V1::CommentsController < Api::V1::CoreController
  allow_everyone only: [:create]

  private

  def permitted_params
    params.permit(comment: [:body, :mt_assignment_id, :mt_hit_id, :mt_worker_id])
  end
end

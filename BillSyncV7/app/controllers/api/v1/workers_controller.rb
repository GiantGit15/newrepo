class Api::V1::WorkersController < Api::V1::CoreController
  allow_everyone only: [:show]

  def show
    if resource
      respond_with(resource)
    else
      respond_to do |format|
        format.json { render json: {errors: 'Not found'}, status: 404 }
      end
    end
  end

  protected

  def resource
    @worker ||= Worker.find_or_create_by(mt_worker_id: params[:id])
  end
end

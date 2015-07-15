class Api::V1::SurveysController < Api::V1::CoreController
  allow_everyone only: [:create, :index]

  def index
    hit = Hit.find_by!(mt_hit_id: params[:hit_id])
    render json: hit.invoice_surveys.collect(&:survey_attributes)
  end

  def create
    Mturk::Surveys::Creator.create_surveys_with(permitted_params)
    head 200
  end

  private

  def permitted_params
    params.permit(:mt_worker_id, :mt_hit_id, :mt_assignment_id, surveys: survey_params)
  end

  def survey_params
    [
      :is_invoice, :vendor_present, :address_present, :amount_due_present,
      :is_marked_through, :invoice_id, :line_items_count,
      :address_reference,
      invoice_pages: [:page_number, :invoice_id, :line_items_count]
    ]
  end
end

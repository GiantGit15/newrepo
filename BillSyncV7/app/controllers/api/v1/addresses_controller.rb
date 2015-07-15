class Api::V1::AddressesController < Api::V1::CoreController
  allow_everyone only: [:create, :invoice]

  def invoice
    hit = Hit.find_by(mt_hit_id: params[:hit_id])
    respond_with hit.invoice
  end

  def create
    if params[:mt_hit_id].present?
      create_from_hit
    else
      super
    end
  end

  def merge
    resource.merge_address!(params[:parent_id])
    head 200
  end

  def unmerge
    resource.unmerge_address!
    head 200
  end

  private

  def create_from_hit
    instance = Mturk::Addresses::Creator.create_address_with(permitted_params)
    if instance.errors.any?
      render json: instance.errors, status: 403
    else
      render json: instance
    end
  end

  def permitted_params
    params.permit(:mt_worker_id, :mt_hit_id, :mt_assignment_id, :qb_class_id, surveys: survey_params, address: survey_params)
  end

  def survey_params
    [
      :name, :address1, :address2, :city, :state, :zip, :invoice_id, :qb_class_id,
      :addressable_id, :addressable_type
    ]
  end

  def end_of_association_chain
    current_user.addresses
  end
end

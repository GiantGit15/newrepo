class Api::V1::IndividualsController < Api::V1::CoreController

  skip_load_and_authorize_resource only: [:update_password, :authorization_scopes, :set_company, :unlink]
  skip_authorization_check only: [:set_company, :unlink]

  before_action :set_security_headers
  before_action :process_authorization_scopes, only: [:create, :update]


  def create
    resource.randomize_password
    if params[:user_id].present?
      resource.users << User.find(params[:user_id])
    else
      build_resource
      current_user.individuals << resource
    end

    super
  end

  def authorization_scopes
    authorize! :read, Individual
    collection = current_user.expense_accounts + current_user.vendors + current_user.qb_classes
    respond_with collection, each_serializer: Api::V1::AuthorizationScopeSerializer
  end

  def update
    individual = Individual.find(params[:id])
    a = Appointment.where(user_id: current_user.id, individual_id: individual.id).first
    a.update_attribute(:role_id, params[:individual][:role_id]) if params[:individual] && params[:individual][:role_id]
    params[:individual].try(:delete, :role_id)
    super
  end

  def set_company
    current_individual.update_attribute(:last_selected_company_id, params[:company_id])
    render nothing: true
  end

  def unlink
    individual = Individual.find(params[:id])
    current_user.appointments.where(individual_id: individual.id).first.delete
    render nothing: true
  end

  def show
    authorize! :read, Individual
    super
  end

  private

  def process_authorization_scopes
    return unless params[:individual]
    return unless params.has_key?(:authorization_scopes) || params[:individual].has_key?(:authorization_scopes)

    src = (params[:individual].delete(:authorization_scopes) || params[:authorization_scopes]) or []
    src = src ? src : []

    expense_account_ids = params[:individual][:permitted_expense_account_ids] = []
    qb_classes_ids = params[:individual][:permitted_qb_class_ids] = []
    vendor_ids = params[:individual][:permitted_vendor_ids] = []

    src.each do |scope_hash|
      case scope_hash[:type]
      when "Expense" then expense_account_ids << scope_hash[:id]
      when "Vendor" then vendor_ids << scope_hash[:id]
      when "QBClass" then qb_classes_ids << scope_hash[:id]
      end
    end
  end

  def permitted_params
    params.permit(individual: [
      :name, :email, :role_id, :limit_min, :limit_max,:mobile_phone, :inviter_name,
      :permitted_expense_account_ids => [], :permitted_qb_class_ids => [],
      :permitted_vendor_ids => []]
    )
  end

  def end_of_association_chain
    current_user.individuals.visible
  end

  def build_resource
    @individual ||= Individual.find_by(email: permitted_params[:individual][:email]) || Individual.new(permitted_params[:individual])
  end

  def set_security_headers
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

end

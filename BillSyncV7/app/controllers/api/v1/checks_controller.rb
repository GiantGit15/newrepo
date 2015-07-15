class Api::V1::ChecksController < Api::V1::CoreController
  skip_authorization_check only: [:index]
  skip_load_and_authorize_resource only: [:index]

  private

  def end_of_association_chain
    current_user.checks.where("sent_date > ?", 14.days.ago).order("number DESC")
  end
end

class Api::V1::DilbertImagesController < Api::V1::CoreController
  skip_authorization_check only: [:index]
  skip_load_and_authorize_resource only: [:index]

  def index
    respond_with [DilbertImage.last_record]
  end
end

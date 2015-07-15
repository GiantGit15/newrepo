class Api::V1::UploadsController < Api::V1::CoreController
  allow_everyone only: [:index]

  def create
    if params["image"] && params["image"].content_type == 'application/pdf'
      respond_with PDFConverter.convert_pdf!(params["image"]), location: ''
    else
      upload = Upload.create(image: params["image"])
      respond_with [upload.as_json], location: ''
    end
  end

  def index
    # authorize :read, Invoice
    respond_with collection
  end

  def permitted_params
    params.permit!
  end

  def collection
    @collection = Invoice.find(params[:invoice_id]).uploads.where(only_png: true)
  end

end

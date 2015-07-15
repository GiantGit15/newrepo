class Api::V1::SmsMessagesController < Api::V1::CoreController
  skip_before_action :authenticate_individual!
  allow_everyone only: [:incoming]

  def incoming
    response.headers["Content-Type"] = "text/xml"
    response = TwilioMessages::MessageParser.new(permited_params).run!
    if response
      render xml: response
    else
      head 200
    end
  end

  private

  def permited_params
    params.permit!
  end

end

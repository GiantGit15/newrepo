# Passes general application config to clients.
class Api::V1::ConfigurationController < Api::V1::CoreController
  allow_everyone

  def resource
    @configuration ||= {
      intercom_app_id: Intercom.app_id,
    }
  end

end

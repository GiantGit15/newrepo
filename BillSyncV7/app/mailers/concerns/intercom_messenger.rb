if Rails.env.production? || Rails.env.staging? || Rails.env.development?
  Figaro.require_keys "INTERCOM_ID_OF_MESSAGE_SENDER"
end

module Concerns

  # Sends Intercom messages via ActionMailer API.
  #
  # Does not support attachments due to technical differencies: multipart
  # messages in ActionMailer, URIs in Intercom.  The recommended practice
  # is to insert links into message body.
  module IntercomMessenger
    extend ActiveSupport::Concern

    attr_reader :intercom_message

    module IntercomDelivery
      def deliver
        self.to.each do |recipient|
          Intercom::Message.delay_for(45.seconds).create(
            :message_type => 'email',
            :subject  => self.subject,
            :body     => self.body.to_s,
            :template => "plain", # or "personal",
            :from => {
              :type => "admin",
              :id   => ENV["INTERCOM_ID_OF_MESSAGE_SENDER"]
            },
            :to => {
              :type => "user",
              :email => recipient
            }
          )
        end
      end
    end

    # For best compatibility, standard ActionMailer method has been overriden.
    # It delivers messages via Intercom.
    #
    # Supported ActionMailer options: +:subject+, +:body+, +:to+.
    def mail options
      super.tap do |m|
        m.extend IntercomDelivery
      end
    end
  end
end

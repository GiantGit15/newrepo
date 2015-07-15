class CustomDeviseMailer < Devise::Mailer
  helper :application # gives access to all helpers defined within `application_helper`.
  include Devise::Controllers::UrlHelpers # Optional. eg. `confirmation_url`
  include Concerns::IntercomMessenger

  def confirmation_instructions(record, token, opts={})
    opts[:subject] = "[billSync] Confirm your email address"
    super
  end

  def individual_created(individual, password)
    @individual = individual
    @password = password
    mail(
      to:       individual.email,
      subject:  "Welcome to BillSync!"
    )
  end
end

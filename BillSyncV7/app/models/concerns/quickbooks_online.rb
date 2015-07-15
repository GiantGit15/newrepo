module Concerns
  module QuickbooksOnline
    extend ActiveSupport::Concern

      def disconnect_from_quickbooks_online!
        update_column(:synced_qb, false)
        service = Quickbooks::Service::AccessToken.new
        service.access_token = user_oauth_intuit
        service.company_id = realm_id
        service.disconnect
        authentications.where(provider: "intuit").destroy_all
      end

      def reset_quickbooks_online_fields
        update_attributes(qb_token: nil,
          qb_secret: nil, realm_id: nil, synced_qb: false,
          qb_company_name: nil,
          token_expires_at: nil,
          reconnect_token_at: nil, qb_wrong_company: nil,
          last_qb_sync: nil)
        accounts.update_all(qb_id: nil, sync_token: nil)
        vendors.update_all(qb_id: nil, sync_token: nil)
        invoices.update_all(qb_id: nil, sync_token: nil)
        line_items.update_all(qb_id: nil, sync_token: nil)
      end

      def save_qbo_settings(access_token, realm_id, response, individual)
        hash = {
          synced_qb: true,
          qb_company_name: response[:legal_name],
          business_name: response[:legal_name],
          token_expires_at: 6.months.from_now.utc,
          reconnect_token_at: 5.months.from_now.utc,
          qb_wrong_company: nil,
          last_qb_sync: nil
        }
        if response[:company_address].present?
          address_attrs = response[:company_address]
          hash[:billing_address1] = address_attrs[:line1]
          hash[:billing_address2] = address_attrs[:line2]
          hash[:billing_city] = address_attrs[:city]
          hash[:billing_state] = address_attrs[:country_sub_division_code]
          hash[:billing_zip] = address_attrs[:postal_code]
        end
        transaction do
          update_attributes(hash)
          authentication_for("intuit").update_attributes(
            token: access_token.token, secret: access_token.secret,
            realm_id: realm_id, individual: individual
          )
        end
      end

      def sync_qb_accounts
        return unless intuit_authentication?
        QuickbooksSync::Users::UserAccountsSync.find(id).sync!
        QuickbooksSync::Workers::InitialSyncWorker.perform_async(id)
      end

      def sync_user_invoices
        invoices.each do |invoice|
          invoice.sync_with_quickbooks
        end
      end

      def user_oauth_intuit
        return @user_oauth_intuit if @user_oauth_intuit
        auth = authentication_for("intuit")
        @user_oauth_intuit ||= OAuth::AccessToken.new($qb_oauth_consumer, auth.token, auth.secret)
      end

      def start_qb_o_syncs
        sync_qb_accounts
      end

      def connected_to_quickbooks?
        authentication_for("intuit").persisted?
      end

      def renew_token!
        auth = authentication_for("intuit")
        return true unless auth.persisted?
        result = get_new_token_for(auth)
        auth.save_renewed_token(result)
      end

      def get_new_token_for(auth)
        service = Quickbooks::Service::AccessToken.new
        service.access_token = user_oauth_intuit
        service.company_id = auth.realm_id
        service.renew
      end

    module ClassMethods

      def find_individual_for_open_id(access_token, current_individual = nil)
        if auth = Authentication.for_open_id({email: access_token.info["email"], uid: access_token["uid"]} ).first
          individual = auth.individual
        elsif individual = Individual.find_by(email: access_token.info["email"])
          auth = individual.authentications.create_intuit_authentication(access_token)
          auth.update_attributes(user_id: individual.last_selected_company.id)
        else
          individual = create_from_open_id(access_token)
        end

        individual
      end

      def create_from_open_id(data)
        info = data.info
        individual = nil
        transaction do
          individual = create_default_individual(info["email"])
          user = User.create
          user.individuals << individual
          user.authentications.create_intuit_authentication(data)
          individual.update_attributes(last_selected_company: user)
        end
        individual
      end

      def create_default_individual(email)
        Individual.create(
          :email => email,
          :password => Devise.friendly_token[0,20]
        )
      end
    end


    included do
      def intuit_authentication?
        @intuit_authentication ||= authentication_for("intuit").valid_intuit_auth?
      end

      alias_method :intuit_authentication, :intuit_authentication?
    end
  end
end

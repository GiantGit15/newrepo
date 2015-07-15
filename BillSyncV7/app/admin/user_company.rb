ActiveAdmin.register User, as: "UserCompany" do
  permit_params :creation_date, :bills_processed, :number_of_locations,
                :number_of_individuals, :location_price, :user_price,
                :bill_price, :payment_price, :credits, :free_bills_per_location,
                :free_users_per_location, :free_payments_per_location

  index do
    selectable_column
    id_column
    column :business_name
    column :last_bill_amount
    column :current_bill_amount
    actions defaults: false do |user|
      link_to "Edit Billing Details", edit_admin_user_company_path(user)
    end
    actions defaults: false do |user|
      link_to "Current Bill Details", current_bills_details_admin_user_company_path(user, user.last_bill) if user.last_bill
    end
  end

  form do |f|
    f.inputs "User Company" do
      f.input :creation_date
      f.input :bills_processed
      f.input :number_of_locations
      f.input :number_of_individuals
      f.input :location_price
      f.input :user_price
      f.input :bill_price
      f.input :payment_price
      f.input :credits
      f.input :free_bills_per_location
      f.input :free_users_per_location
      f.input :free_payments_per_location
    end
    f.actions
  end

  show do
    h3 user_company.business_name
    tabs do
      tab "Overview" do
        attributes_table do
          row :business_name
          row :billing_address1, as: "Billing Address 1"
          row :billing_address2, as: "Billing Address 2"
          row :billing_city
          row :billing_state
          row :billing_zip
          row :creation_date
          row :bills_processed
          row :number_of_locations
          row :number_of_individuals
          row :location_price
          row :user_price
          row :bill_price
          row :payment_price
          row :credits
          row :free_bills_per_location
          row :free_users_per_location
          row :free_payments_per_location
        end
      end

      tab "Billing" do
        attributes_table do
          row("Locations") {|e| "%.2f" % e.location_billing }
          row("Additional Users (Package includes XX)") {|e| "%.2f" % e.users_billing }
          row("Additional Bills") {|e| "%.2f" % e.aditional_bills }
          row("Additional Payments") {|e| "%.2f" % e.aditional_payments }
          row("Credits") {|e| "%.2f" % e.credits_totals }
          row("Total") {|e| "%.2f" % e.total_billing }
        end
      end

    end
  end

  member_action :current_bills_details do
    # @comments = resource.comments
    # This will render app/views/admin/posts/comments.html.erb
  end


end

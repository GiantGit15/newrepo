ActiveAdmin.register WorkerMessage do
  permit_params :body, :subject, :worker_id, :mt_worker_id

  form do |f|
    inputs "Message" do
      input :mt_worker_id
      input :body
      input :subject
    end
    actions
  end

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # permit_params :list, :of, :attributes, :on, :model
  #
  # or
  #
  # permit_params do
  #   permitted = [:permitted, :attributes]
  #   permitted << :other if resource.something?
  #   permitted
  # end


end

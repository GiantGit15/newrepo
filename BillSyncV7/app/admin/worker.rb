ActiveAdmin.register Worker do
  permit_params :mt_worker_id, :training_level, :earning, :earning_rate,
                :score, :created_at, :updated_at, :status, :block_counter,
                :worker_level, :blank_submission_counter, :grant_time,
                :warning_notification_sent_at, :notifications_disabled

  index do
    selectable_column
    column "Id", :id
    column "Mechanical Worker id", :mt_worker_id
    column "Score", :score
    column "Level", :worker_level
    column "Status", :status
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

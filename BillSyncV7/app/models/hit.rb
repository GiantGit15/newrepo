# == Schema Information
#
# Table name: hits
#
#  id          :integer          not null, primary key
#  status      :integer          default(0)
#  mt_hit_id   :string(255)
#  url         :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  hit_type    :integer          default(0)
#  reward      :decimal(8, 2)    default(0.0)
#  invoice_id  :integer
#  submited    :boolean          default(FALSE)
#  page_number :integer          default(1)
#  title       :string(255)
#

class Hit < ActiveRecord::Base
  attr_accessor :mt_hit
  belongs_to :invoice
  has_many :assignments
  has_many :workers, through: :assignments
  has_many :invoice_moderations
  has_many :invoice_surveys, class_name: 'Invoice', foreign_key: :invoice_survey_id
  has_many :turk_transactions

  HIT_VERSION = "prod-testing-6"

  enum hit_type: [:first_review, :second_review, :for_line_item, :marked_through, :for_survey, :for_address]

  def self.find_mt_hit(mt_hit_id)
    return [] unless hit = find_by(mt_hit_id: mt_hit_id)
    if hit.first_review?
      hit.invoice.invoice_moderations.by_one
    elsif hit.second_review?
      [InvoiceModeration.find_by(hit_id: "#{hit.id}")]
    elsif hit.marked_through?
      hit.invoice.invoice_moderations.by_one(:for_marked_through)
    end
  end

  def create_mt_hit
    return unless invoice
    return nil if Rails.env.test?
    self.mt_hit ||= RTurk::Hit.create(title: hit_title) do |hit|
      hit.description = description
      hit.max_assignments = num_assignments
      hit.reward = hit_reward
      hit.lifetime = lifetime
      hit.question(question_url,:frame_height => 1000)
      hit.qualifications.add :approval_rate, approval_rate
      hit.keywords = keywords
      hit.auto_approval_delay = auto_approval_delay
      hit.duration = assignments_duration
    end
  end

  def can_clear_hit?
    invoice_surveys.pluck(:survey_agreement).all?
  end

  def num_assignments
    3
  end

  def set_hit_attributes
    return true if Rails.env.test?
    self.mt_hit_id = mt_hit.id
    self.url       = mt_hit.url
    self.reward    = hit_reward
    self.title     = hit_title
  end

  def assignments_duration
    20.minutes.to_s
  end

    def lifetime
    10.days # Days
  end

  def question_url
    "#{ENV['host']}/app/#/invoice/fromaws"
  end

  def keywords
    %w{
      image invoice categorize transcribe extract data entry transcription
      text easy qualification secure prodfast
    }
  end

  def auto_approval_delay
    10.hour
  end

    def num_assignments
    2 # Per hit
  end

  def hit_reward
    0.05
  end

  def approval_rate
    { gt: 0 }
  end

  def expire!
    begin
      ::Hits::Review.find(id).mt_hit.expire!
    rescue
    end
  end

  def expire_created_hit
    return true unless mt_hit_id
    return true unless persisted? && get_mt_hit
    return true unless ![invoice, invoice_surveys.present?].any?
    begin
      get_mt_hit.set_as_reviewing
      if get_mt_hit.status != 'Reviewable'
        get_mt_hit.disable!
      else
        get_mt_hit.dispose!
      end
    rescue
    end
    true
  end

  def get_mt_hit
    begin
      @get_mt_hit ||= RTurk::Hit.find(mt_hit_id)
    rescue RTurk::InvalidRequest
      false
    end
  end
end

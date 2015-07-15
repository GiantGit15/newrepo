# == Schema Information
#
# Table name: dilbert_images
#
#  id                 :integer          not null, primary key
#  title              :string(255)
#  link               :string(255)
#  guid               :string(255)
#  publication_date   :datetime
#  description        :string(255)
#  original_image_url :string(255)
#  image_file_name    :string(255)
#  image_content_type :string(255)
#  image_file_size    :integer
#  image_updated_at   :datetime
#  created_at         :datetime
#  updated_at         :datetime
#

class DilbertImage < ActiveRecord::Base

  has_attached_file :image

  validates_attachment :image, content_type: { content_type: ["image/jpg", "image/jpeg", "image/png", "image/gif"] }

  validates :title, presence: true
  validates :publication_date, uniqueness: true

  def self.last_record
    order('publication_date DESC').first
  end

  def local_image_url
    if !image.path.nil?
      image_local_path = image.url
    end
    return image_local_path if Rails.env.development?
    image? ? s3_url : image.url
  end

  def s3_url
    base_url = "https://billsync1.s3.amazonaws.com/dilbert_images/"
    path = image.url.split('billsync1/dilbert_images/')
    path.shift
    path.unshift(base_url)
    path.join
  end
end

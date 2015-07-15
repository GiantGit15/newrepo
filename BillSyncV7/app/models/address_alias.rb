class AddressAlias < ActiveRecord::Base
  has_many :addresses
  belongs_to :user
  belongs_to :selected_address, class_name: 'Address', foreign_key: 'selected_id'
end

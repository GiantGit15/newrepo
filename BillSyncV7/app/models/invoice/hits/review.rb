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

# Hit class to review and pay workers after a hit is finished.
class Hits::Review < Hit

  def self.complete!(id, already_aproved = false)
    builder = find(id)
    return false unless builder.mt_hit
    builder.set_as_reviewing!
    builder.aprove_mt_assignments! unless already_aproved
    builder.dispose_mt_hit!
    builder.update_attributes(submited: true)
    true
  end

  def self.pay_for(id)
    builder = find(id)
    return false unless builder.mt_hit
    builder.aprove_mt_assignments!
    true
  end

  def self.extend_hit!(id)
    builder = find(id)
    return false unless builder.mt_hit
    builder.extend_hit
    true
  end

  def extend_hit
    if mt_hit.status == "Disposed"
      return false
    else
      mt_hit.extend!({assignments: 1, seconds: 10.days})
    end
  end

  def mt_hit
    begin
      @mt_hit ||= RTurk::Hit.find(mt_hit_id)
    rescue RTurk::InvalidRequest
      false
    end
  end

  def set_as_reviewing!
    begin
      mt_hit.set_as_reviewing!
    rescue
    end
  end

  def aprove_mt_assignments!
    mt_hit.assignments.each do |mt_assignment|
      begin
        mt_assignment.approve!
      rescue RTurk::InvalidRequest
      end
    end
  end

  def dispose_mt_hit!
    begin
      if mt_hit.status != 'Reviewable'
        mt_hit.disable!
      else
        mt_hit.dispose!
      end
    rescue

    end
  end
end

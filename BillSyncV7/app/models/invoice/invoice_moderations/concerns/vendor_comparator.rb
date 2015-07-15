module InvoiceModerations::Concerns::VendorComparator
  extend ActiveSupport::Concern

  attr_accessor :vendor_results, :im3, :vendor

  def calculate_vendor_results
    get_vendor_results
    if vendor_match? && vendor
      invoice.update_column(:vendor_id, vendor.id)
    elsif build_vendor && builder_vendor_match? && @vendor_build.vendor # work out why vendor gets default to nil
      invoice.update_column(:vendor_id, @vendor_build.vendor.id)
    end
  end

  def vendor_match?
    vendor_ids = [im1, im2, im3].compact.collect(&:vendor_id).compact
    if v_id = vendor_ids.compact.detect {|e| vendor_ids.count(e) > 1 }
      @vendor = Vendor.find(v_id)
      return true
    end
    # Array of fz results[[vendor_record, dice_score, lev_score]...]
    return false unless get_vendor_results.any?
    return false unless result = vendor_results.compact.detect {|e| vendor_results.count(e) > 1 }
    @vendor = result
    result ? true : false
  end

  def get_vendor_results
    return @vendor_results if @vendor_results
    fz = FuzzyMatch.new(invoice.user.vendors, :read => :comparation_string,
      must_match_at_least_one_word: true, find_with_score: true)
    @vendor_results ||= [im1, im2, im3].compact.collect do |im|
      element = fz.find(vendor_string_for(im))
      next unless element && [element.second, element.third].all? {|e| e > 0.8 }
      element.first
    end
  end

  def vendor_string_for(im)
    [im.name, im.address1, im.address2, im.city, im.state, im.zip].join(", ")
  end

  def should_post_a_job_for_vendor?
    [!vendor_match?, !builder_vendor_match?]
  end

  def builder_vendor_match?
    build_vendor.missmatch.blank? || im3.present?
  end

  def build_vendor
    return @vendor_build if @vendor_build
    @vendor_build = InvoiceModerations::VendorBuilder.new([im1, im2, im3].compact, invoice.user, nil)
    @vendor = @vendor_build.vendor
    vendor.email = select_vendor_email unless vendor.email
    if vendor.new_record? && !vendor.name.present?
      vendor.created_by = :by_worker
      vendor.source = :worker
    end
    vendor.save validate: false
    @vendor_build
  end

  def select_vendor_email
    im1.email if match_email?
    worker1, worker2 = [im1.worker, im2.worker]
    return unless worker1 && worker2
    return im1.email if worker1 && !worker2
    return im2.email if worker2 && !worker1
    worker1.score > worker2.score ? im1.email : im2.email
  end

  def update_ims_vendor_id
    [im1,im2, im3].compact.each do |im|
      im.update_column(:vendor_id, @vendor.id)
    end
  end

  def match_email?
    im1.email.present? && im1.email == im2.email
  end

end

module Concerns

  # This module patches non-POST and non-GET default actions defined by
  # InheritedResources.  They no longer rely on #respond_with which does not
  # work properly in such actions and does not call resource#to_json.
  #
  # See: https://github.com/rails/rails/blob/v4.1.1/actionpack/lib/action_controller/metal/responder.rb#L202-L214
  module FixInheritedResources

    # Looks like #respond_with fails when used in non-POST and non-GET requests.
    # Using it in #update actions leads to :no_content being rendered.
    #
    # TODO Remove when mentioned problem will disappear.  This may happen after
    # TODO some major gem upgade, maybe ActiveModelSerializers to 0.10.x
    # TODO or Rails to 4.2 or Responders to 2.x or InheritedResources, who knows?
    def respond_with *args
      if request.post? || request.get?
        super
      else
        raise "Active Model Serializers are not fully compatible with Rails' " +
          "#respond_with method.  You may continue to use it in GET and POST " +
          "requests, but in other cases rather stick to `render json: resource`."
      end
    end

    # PUT /resources/1
    def update(options={}, &block)
      object = resource

      if update_resource(object, resource_params)
        options[:location] ||= smart_resource_url
      end

      render options.merge json: object
    end
    alias :update! :update

    # DELETE /resources/1
    def destroy(options={}, &block)
      object = resource
      options[:location] ||= smart_collection_url

      destroy_resource(object)

      render options.merge json: object
    end
    alias :destroy! :destroy

  end
end

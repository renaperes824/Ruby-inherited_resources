module InheritedResources #:nodoc:
  module BaseHelpers

    protected

      # This is how the collection is loaded.
      #
      # You might want to overwrite this method if you want to add pagination
      # for example. When you do that, don't forget to cache the result in an
      # instance_variable:
      #
      #   def collection
      #     @projects ||= end_of_association_chain.paginate(params[:page]).all
      #   end
      #
      def collection
        get_collection_ivar || set_collection_ivar(end_of_association_chain.find(:all))
      end

      # This is how the resource is loaded.
      #
      # You might want to overwrite this method when you are using permalink.
      # When you do that, don't forget to cache the result in an
      # instance_variable:
      #
      #   def resource
      #     @project ||= end_of_association_chain.find_by_permalink!(params[:id])
      #   end
      #
      # You also might want to add the exclamation mark at the end of the method
      # because it will raise a 404 if nothing can be found. Otherwise it will
      # probably render a 500 error message.
      #
      def resource
        get_resource_ivar || set_resource_ivar(end_of_association_chain.find(params[:id]))
      end

      # This method is responsable for building the object on :new and :create
      # methods. You probably won't need to change it. Again, if you overwrite
      # don't forget to cache the result in an instance_variable.
      #
      def build_resource(attributes = {})
        get_resource_ivar || set_resource_ivar(end_of_association_chain.send(method_for_build, attributes))
      end

      # This class allows you to set a instance variable to begin your
      # association chain. For example, usually your projects belongs to users
      # and that means that they belong to the current logged in user. So you
      # could do this:
      #
      #   def begin_of_association_chain
      #     @current_user
      #   end
      #
      # So every time we instantiate a project, we will do:
      #
      #   @current_user.projects.build(params[:project])
      #   @current_user.projects.find(params[:id])
      #
      # The variable set in begin_of_association_chain is not sent when building
      # urls, so this is never going to happen when calling resource_url:
      #
      #   project_url(@current_user, @project)
      #
      # If the user actually scopes the url, you should use belongs_to method
      # and declare that projects belong to user.
      #
      def begin_of_association_chain
        nil
      end

      # Returns if the object has a parent. When only base helpers are loaded,
      # it's always false.
      #
      def parent?
        false
      end

      # Overwrite this method to provide other interpolation options when
      # the flash message is going to be set.
      #
      # You cannot overwrite :resource_name and :default options using this
      # method. Check <tt>set_flash_message!</tt> for more information.
      #
      def interpolation_options
        { }
      end

    private

      # Fast accessor to resource_collection_name
      #
      def resource_collection_name #:nodoc:
        resources_configuration[:self][:collection_name]
      end

      # Fast accessor to resource_instance_name
      #
      def resource_instance_name #:nodoc:
        resources_configuration[:self][:instance_name]
      end

      # This methods gets your begin_of_association_chain and returns the
      # scoped association.
      #
      def end_of_association_chain #:nodoc:
        if begin_of_association_chain || parent?
          begin_of_association_chain.send(resource_collection_name)
        else
          resource_class
        end
      end

      # Returns the appropriated method to build the resource.
      #
      def method_for_build #:nodoc:
        (begin_of_association_chain || parent?) ? :build : :new
      end

      # Get resource ivar based on the current resource controller.
      #
      def get_resource_ivar #:nodoc:
        instance_variable_get("@#{resource_instance_name}")
      end

      # Set resource ivar based on the current resource controller.
      #
      def set_resource_ivar(resource) #:nodoc:
        instance_variable_set("@#{resource_instance_name}", resource)
      end

      # Get collection ivar based on the current resource controller.
      #
      def get_collection_ivar #:nodoc:
        instance_variable_get("@#{resource_collection_name}")
      end

      # Set collection ivar based on the current resource controller.
      #
      def set_collection_ivar(collection) #:nodoc:
        instance_variable_set("@#{resource_collection_name}", collection)
      end

      # Helper to set flash messages. It's powered by I18n API.
      # It checks for messages in the following order:
      #
      #   flash.controller_name.action_name.status
      #   flash.actions.action_name.status
      #
      # If none is available, a default message is set. So, if you have
      # a CarsController, create action, it will check for:
      #
      #   flash.cars.create.status
      #   flash.actions.create.status
      #
      # The statuses can be :notice (when the object can be created, updated
      # or destroyed with success) or :error (when the objecy cannot be created
      # or updated).
      #
      # Those messages are interpolated by using the resource class human name.
      # This means you can set:
      #
      #   flash:
      #     actions:
      #       create:
      #         notice: "Hooray! {{resource_name}} was successfully created!"
      #
      # But sometimes, flash messages are not that simple. Going back
      # to cars example, you might want to say the brand of the car when it's
      # updated. Well, that's easy also:
      #
      #   flash:
      #     cars:
      #       update:
      #         notice: "Hooray! You just tuned your {{car_brand}}!"
      #
      # Since :car_name is not available for interpolation by default, you have
      # to overwrite interpolation_options.
      #
      #   def interpolation_options
      #     { :car_brand => @car.brand }
      #   end
      #
      # Then you will finally have:
      #
      #   'Hooray! You just tuned your Aston Martin!'
      #
      # If your controller is namespaced, for example Rare::CarsController,
      # the messages will be checked in the following order:
      #
      #   flash.rare.cars.create.status
      #   flash.rare.actions.create.status
      #   flash.cars.create.status
      #   flash.actions.create.status
      #
      def set_flash_message!(status, default_message = '')
        return flash[status] = default_message unless defined?(::I18n)

        options = {
          :default  => default_message || '',
          :resource_name => resource_class ? resource_class.human_name : 'Resource',
        }.merge(interpolation_options)

        defaults = []
        slices   = controller_path.split('/')

        while slices.size > 0
          defaults << :"flash.#{slices.fill(controller_name, -1).join('.')}.#{action_name}.#{status}"
          defaults << :"flash.#{slices.fill(:actions, -1).join('.')}.#{action_name}.#{status}"
          slices.shift
        end

        options[:default] = defaults.push(options[:default])
        options[:default].flatten!

        message = ::I18n.t options[:default].shift, options
        flash[status] = message unless message.blank?
      end

      # Used to allow to specify success and failure within just one block:
      #
      #   def create
      #     create! do |success, failure|
      #       failure.html { redirect_to root_url }
      #     end
      #   end
      #
      def respond_to_with_dual_blocks(success, dual_block, options={}, &block) #:nodoc:
        responder = ActionController::MimeResponds::Responder.new(self)

        if dual_block
          if dual_block.arity == 2
            dumb_responder = InheritedResources::DumbResponder.new
            if success
              dual_block.call(responder, dumb_responder)
            else
              dual_block.call(dumb_responder, responder)
            end
          else
            dual_block.call(responder)
          end

          # Try to respond with the block given
          responder.respond_except_any
        end

        respond_to(options.merge!(:responder => responder, :prioritize => :html), &block) unless performed?
      end

  end
end

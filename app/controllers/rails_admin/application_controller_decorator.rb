# rails_admin-1.0 ready
module RailsAdmin
  ApplicationController.class_eval do

    attr_reader :context_abstract_model

    def to_model_name(param_model_name)
      model_name = param_model_name.split('~').collect(&:camelize).join('::')
      #Patch
      if (m = [Setup, Cenit, Forms, Mongoid::Tracer].detect { |m| m.const_defined?(model_name, false) })
        model_name = "#{m}::#{model_name}"
      end
      model_name
    end

    def get_model
      #Patch
      @model_name = to_model_name(name = params[:model_name].to_s)
      # Transferring shared collections to cross shared collections.
      # TODO Change to cross shared collection after model renaming
      if @model_name == 'Setup::SharedCollection'
        @model_name = Setup::CrossSharedCollection.to_s
      end
      @data_type = nil
      unless (@abstract_model = RailsAdmin::AbstractModel.new(@model_name))
        if (@data_type = get_data_type(params[:model_name].to_s))
          abstract_model_class = @data_type.records_model.is_a?(Class) ? AbstractModel : MongoffAbstractModel
          @abstract_model = abstract_model_class.new(@data_type.records_model)
        end
      end

      if @abstract_model.nil? || (@model_config = @abstract_model.config).excluded?
        fail(RailsAdmin::ModelNotFound)
      end

      @dashboard_group_ref =
        if ecommerce_model?
          'ecommerce'
        else
          group_index = (path = @model_config.dashboard_group_path).length == 1 ? 0 : path.length - 2
          path[group_index]
        end
      @dashboard_group = dashboard_group(@dashboard_group_ref)

      @properties = @abstract_model.properties
    end

    def get_data_type(param_model_name)
      data_type = nil
      slugs = param_model_name.split('~')
      if slugs.size == 2
        ns = Setup::Namespace.where(slug: slugs[0]).first
        data_type = Setup::DataType.where(namespace: ns.name, slug: slugs[1]).first if ns
      elsif param_model_name.start_with?('dt')
        data_type = Setup::DataType.where(id: param_model_name.from(2)).first
      end
      data_type
    end

    def get_object
      #Patch
      action_class = RailsAdmin::Config::Actions.find(@_action_name.to_sym).class
      action_class.loading_member do
        if (@object = @abstract_model.get(params[:id]))
          unless @object.is_a?(Mongoff::Record) || @object.class == @abstract_model.model
            #Right model context for object
            @model_config = RailsAdmin::Config.model(@object.class)
            @abstract_model = @model_config.abstract_model
          end
          @object
        elsif (model = @abstract_model.model)
          @object = model.try(:find_by_id, params[:id])
        end
      end
      @object || fail(RailsAdmin::ObjectNotFound)
    end

    rescue_from ::NameError do
      send_file 'public/404.html', type: 'text/html; charset=utf-8', disposition: :inline, status: :not_found
    end
  end
end

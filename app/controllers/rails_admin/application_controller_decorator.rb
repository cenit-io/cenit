module RailsAdmin
  ApplicationController.class_eval do

    alias_method :rails_admin_to_model_name, :to_model_name

    def to_model_name(param)
      model_name = rails_admin_to_model_name(param)
      if (m = [Setup, Cenit, Forms].detect { |m| m.const_defined?(model_name, false) })
        "#{m}::#{model_name}"
      else
        model_name
      end
    end

    def get_model
      #Patch
      @model_name = to_model_name(name = params[:model_name].to_s)
      #TODO Transferring shared collections to cross shared collections. REMOVE after migration
      if @model_name == Setup::SharedCollection.to_s && !User.current_super_admin?
        @model_name = Setup::CrossSharedCollection.to_s
      end
      @data_type = nil
      unless (@abstract_model = RailsAdmin::AbstractModel.new(@model_name))
        if (slugs = name.to_s.split('~')).size == 2
          if (ns = Setup::Namespace.where(slug: slugs[0]).first)
            @data_type = Setup::DataType.where(namespace: ns.name, slug: slugs[1]).first
          end
        else
          @data_type = Setup::DataType.where(id: name.from(2)).first if name.start_with?('dt')
        end
        if @data_type
          abstract_model_class =
            if (model = @data_type.records_model).is_a?(Class)
              RailsAdmin::AbstractModel
            else
              RailsAdmin::MongoffAbstractModel
            end
          @abstract_model = abstract_model_class.new(model)
        end
      end

      fail(RailsAdmin::ModelNotFound) if @abstract_model.nil? || (@model_config = @abstract_model.config).excluded?

      @properties = @abstract_model.properties
    end

    def get_object
      #Patch
      if (@object = @abstract_model.get(params[:id]))
        unless @object.is_a?(Mongoff::Record) || @object.class == @abstract_model.model
          @model_config = RailsAdmin::Config.model(@object.class)
          @abstract_model = @model_config.abstract_model
        end
        @object
      elsif (model = @abstract_model.model)
        @object = model.try(:find_by_id, params[:id])
      end
      @object || fail(RailsAdmin::ObjectNotFound)
    end
  end
end

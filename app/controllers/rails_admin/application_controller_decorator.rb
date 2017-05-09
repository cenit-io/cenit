module RailsAdmin
  ApplicationController.class_eval do

    def to_model_name(param_model_name)
      model_name = param_model_name.split('~').collect(&:camelize).join('::')
      if (m = [Setup, Cenit, Forms].detect { |m| m.const_defined?(model_name, false) })
        model_name = "#{m}::#{model_name}"
      end
      model_name
    end

    def get_model
      #Patch
      @model_name = to_model_name(params[:model_name])
      #TODO Transferring shared collections to cross shared collections. REMOVE after migration
      if @model_name == Setup::SharedCollection.to_s
        @model_name = Setup::CrossSharedCollection.to_s
      end
      @data_type = nil
      unless (@abstract_model = RailsAdmin::AbstractModel.new(@model_name))
        if (@data_type = get_data_type(params[:model_name].to_s))
          abstract_model_class = @data_type.records_model.is_a?(Class) ? AbstractModel : MongoffAbstractModel
          @abstract_model = abstract_model_class.new(@data_type.records_model)
        end
      end

      fail(RailsAdmin::ModelNotFound) if @abstract_model.nil? || (@model_config = @abstract_model.config).excluded?

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

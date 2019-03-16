module RailsAdmin
  module Config
    module Actions
      class PullImport < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::CrossSharedCollection::COLLECTING_PROPERTIES.collect do |property|
            model = Setup::CrossSharedCollection.reflect_on_association(property).klass
            if model.include?(Setup::ClassHierarchyAware)
              model.class_hierarchy
            else
              model
            end
          end.flatten + [Setup::Collection]
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            form_config = RailsAdmin::Config.model(Forms::JsonDataImport)
            view = :form
            model = @abstract_model.model rescue nil
            if model
              if (data = params[form_config.abstract_model.param_key]) &&
                (@form_object = Forms::JsonDataImport.new(file: (file = data[:file]), data: (data = data[:data]))).valid?
                begin
                  if model == Setup::Collection
                    if (data = @form_object.json_data).length == 1
                      data = data[0]
                    else
                      fail 'Array data is not allowed for pulling collections'
                    end
                  else
                    collecting_property = Setup::CrossSharedCollection::COLLECTING_PROPERTIES.detect { |name| Setup::CrossSharedCollection.reflect_on_association(name).klass >= model }
                    data = { collecting_property => @form_object.json_data }.with_indifferent_access
                  end
                  do_flash_process_result Setup::PullImport.process(data: data.to_json, discard_collection: model != Setup::Collection)
                  view = nil
                rescue Exception => ex
                  flash[:error] = ex.message
                end
              end
            else
              flash[:error] = 'Error loading model'
            end
            if view
              @form_object ||= Forms::JsonDataImport.new
              @model_config = form_config
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the import data specification', @form_object.errors.full_messages)
              end

              render view
            else
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'icon-arrow-down'
        end
      end
    end
  end
end
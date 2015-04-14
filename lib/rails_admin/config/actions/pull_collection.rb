module RailsAdmin
  module Config
    module Actions

      class PullCollection < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          false
        end

        register_instance_option :only do
          Setup::SharedCollection
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            @parameter_values = (params[:pull_parameters] && params[:pull_parameters].to_hash) || {}
            @missing_parameters = []
            @object.pull_parameters.each { |pull_parameter| @missing_parameters << pull_parameter.parameter unless @parameter_values[pull_parameter.parameter].present? }
            @ids_to_update = {}
            hash_data = @object.data_with(@parameter_values)
            Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
              if data = hash_data[relation.name.to_s]
                data.each do |item|
                  if record = relation.klass.where(name: item['name']).first
                    item['id'] = record.id.to_s
                    unless records = @ids_to_update[relation.name.to_s]
                      records = @ids_to_update[relation.name.to_s] = []
                    end
                    records << record
                  end
                end
              end
            end
            if libraries = @ids_to_update['libraries']
              data = hash_data['libraries']
              libraries.each do |library|
                if library_data = data.detect { |item| item['name'] == library.name }
                  if schemas_data = library_data['schemas']
                    library.schemas.each do |schema|
                      if schema_data = schemas_data.detect { |sch| sch['uri'] == schema.uri }
                        schema_data['id'] = schema.id.to_s
                      end
                    end
                  end
                  if data_type_data = library_data['file_data_types']
                    library.file_data_types.each do |file_data_type|
                      if data_type_data = data_type_data.detect { |dt| dt['name'] == file_data_type.name }
                        data_type_data['id'] = file_data_type.id.to_s
                      end
                    end
                  end
                end
              end
            end
            errors = []
            if @missing_parameters.blank? && params[:_pull]
              begin
                collection = Setup::Collection.new
                collection.from_json(hash_data)
                collection.errors.full_messages.each { |msg| errors << msg } unless Cenit::Utility.save(collection)
              rescue Exception => ex
                raise ex
                errors << ex.message
              end
              if errors.blank?
                redirect_to_on_success
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash[:error] += %(<br>- #{errors[0..4].join('<br>- ')}).html_safe
                if errors.length - 5 > 0
                  flash[:error] += "<br>- and other #{errors.length - 5} errors.".html_safe
                end
                redirect_to back_or_index
              end
            else
              if params[:_pull]
                flash[:error] = 'Missing parameters' if @missing_parameters.present?
              else
                @missing_parameters = []
              end
              render @action.template_name
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
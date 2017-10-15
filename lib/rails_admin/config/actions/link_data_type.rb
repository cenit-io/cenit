module RailsAdmin
  module Config
    module Actions
      class LinkDataType < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          false
        end

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get, :patch]
        end

        register_instance_option :controller do
          proc do

            data_type = nil
            Forms::DataTypeSelector.collection.drop
            selector_config = RailsAdmin::Config.model(Forms::DataTypeSelector)
            render_form = true
            if (select_data = params[selector_config.abstract_model.param_key])
              select_data.permit!
              if (@form_object = Forms::DataTypeSelector.new(select_data)).valid?
                begin
                  data_type = @form_object.data_type
                  data_type.navigation_link = true
                  render_form = !data_type.save
                rescue Exception => ex
                  flash[:error] = ex.message
                end
              end
            end
            if render_form
              data_type_model = nil
              unless @form_object
                scope = { navigation_link: { '$in': [false, nil] } }
                data_type_model = params[:data_type_model].to_s.constantize rescue nil
                @action.bindings[:custom_model_config] =
                  if data_type_model
                    scope[:_type] = data_type_model.to_s
                    RailsAdmin::Config.model(data_type_model)
                  else
                    RailsAdmin::Config.model(data_type_model = Setup::DataType)
                  end
                @form_object = Forms::DataTypeSelector.new(scope: scope)
              end
              if data_type_model && !data_type_model.where(navigation_link: { '$in': [nil, false] }).exists?
                flash[:warning] = "All #{@action.bindings[:custom_model_config].label_plural} are already linked"
                redirect_to dashboard_path
              else
                @model_config = selector_config
                if @form_object.errors.present?
                  do_flash_now(:error, 'There are errors selecting the data type', @form_object.errors.full_messages)
                end
                @form_object.save(validate: false)
                render :form
              end
            else
              if data_type
                redirect_to rails_admin.index_path(model_name: data_type.records_model.to_s.underscore.gsub('/', '~'))
              else
                redirect_to dashboard_path
              end
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-link'
        end
      end
    end
  end
end

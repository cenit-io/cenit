module RailsAdmin
  module Config
    module Actions
      class Chart < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            begin
              bindings[:abstract_model].model.data_type.present?
            rescue
              false
            end
          else
            false
          end
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            model = abstract_model.model rescue nil
            if model && (data_type = model.data_type)
              if data_type.records_model.modelable?
                data_type.chart_rendering = !data_type.chart_rendering
                data_type.save
                flash[:success] =
                  if data_type.chart_rendering
                    "Data type #{data_type.custom_title} chart rendering enabled"
                  else
                    "Data type #{data_type.custom_title} chart rendering disabled"
                  end
              else
                flash[:error] = "Model #{data_type.title} is not an object model"
              end
              redirect_to rails_admin.index_path(model_name: model.to_s.underscore.gsub('/', '~'))
            else
              redirect_to back_or_index
            end

          end
        end
        register_instance_option :i18n_key do
          model = bindings[:abstract_model].model rescue nil
          if model && (data_type = model.data_type)
            "#{key.to_s}.#{data_type.chart_rendering ? 'hide' : 'show'}"
          end
        end

        register_instance_option :link_icon do
          'fa fa-bar-chart'
        end
      end
    end
  end
end
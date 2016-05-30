module RailsAdmin
  module Config
    module Actions
      class BaseExpand < RailsAdmin::Config::Actions::Base

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            @bulk_ids = params.delete(:bulk_ids)
            if (object_ids = params.delete(:object_ids))
              @bulk_ids = object_ids
            end
            source = (@object && [@object.id.to_s]) || @bulk_ids
            options_config = RailsAdmin::Config.model(Forms::ExpandOptions)
            if (options_params = params[options_config.abstract_model.param_key])
              options_params = options_params.select { |k, _| %w(segment_shortcuts).include?(k.to_s) }.permit!
            else
              options_params = {}
            end
            @form_object = Forms::ExpandOptions.new(options_params)
            result = nil
            begin
              result = Setup::DataTypeExpansion.process(@form_object.attributes.merge(source: source))
            rescue Exception => ex
              do_flash(:error, 'Error expanding data type:', ex.message)
            end if params[:_save]
            if result
              do_flash_process_result(result)
              redirect_to back_or_index
            else
              report = Setup::DataType.shutdown(@object, report_only: true)
              @object.instance_variable_set(:@_to_shutdown, report[:destroyed].collect(&:data_type).uniq) if report[:destroyed]
              @object.instance_variable_set(:@_to_reload, report[:affected].collect(&:data_type).uniq) if report[:affected]
              @model_config = options_config
              render :form
            end
          end
        end

        register_instance_option :link_icon do
          'icon-zoom-in'
        end

        register_instance_option :pjax? do
          false
        end
      end
    end
  end
end

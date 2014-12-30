module RailsAdmin
  module Config
    module Actions

      class EdiExport < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model.respond_to?(:data_type_id)
          else
            false
          end
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            if field_sep = params[:field_separator]
              field_sep = field_sep.to_sym if field_sep == :by_fixed_length.to_s
              render plain: @object.to_edi(field_separator: field_sep)
            else
              @field_separator_options = [['By fixed length', 'by_fixed_length'], ['Using separator (*)', '*']]
              render @action.template_name
            end
          end
        end

        register_instance_option :link_icon do
          'icon-download'
        end

      end

    end
  end
end
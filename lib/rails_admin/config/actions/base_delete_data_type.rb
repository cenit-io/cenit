module RailsAdmin
  module Config
    module Actions
      class BaseDeleteDataType < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [Setup::JsonDataType, Setup::FileDataType]
        end

        register_instance_option :http_methods do
          [:get, :delete]
        end

        register_instance_option :controller do
          proc do

            create_selector_token = false
            scope =
              if @object
                Setup::DataType.where(id: @object.id)
              elsif (@bulk_ids = params[:bulk_ids] || []).present?
                Setup::DataType.any_in(id: @bulk_ids)
              else
                create_selector_token = true
                if (selector_token = ::Cenit::Token.where(token: params[:selector_token]).first) &&
                  (selector = selector_token.data).is_a?(Hash)
                  selector_token.destroy
                  Setup::DataType.where(selector)
                else
                  ids = list_entries(@abstract_model.config, :simple_delete_data_type).limit(1000).collect(&:id)
                  Setup::DataType.where(:id.in => ids)
                end
              end
            if params[:delete] # DELETE
              if @object
                unless @object.destroy
                  do_flash(:error, "Data type #{@object.custom_title} could not be destroyed", @object.errors.full_messages)
                end
              else
                do_flash_process_result Setup::Deletion.process(model_name: @abstract_model.model_name, selector: scope.selector)
              end
              redirect_to back_or_index
            else
              if create_selector_token
                @selector_token = Cenit::Token.create(data: scope.selector, token_span: 300).token
              end
              @object = Object.new
              @object.instance_variable_set(:@_to_delete, scope) if scope.count.positive?
              render :delete_data_types
            end
          end
        end

        register_instance_option :link_icon do
          'icon-remove'
        end
      end
    end
  end
end
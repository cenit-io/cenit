module RailsAdmin
  module Config
    module Actions
      class JsonEdit < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :put]
        end

        register_instance_option :controller do
          proc do
            if (json_data = params[:json_data])
              begin
                @object.from_json(json_data)
                @object.save
              rescue Exception => ex
                @object.errors.add(:base, ex.message)
              end
              if @object.errors.present?
                @json_data = json_data.is_a?(String) ? json_data : json_data.to_json
                do_flash(:error, 'Errors updating', @object.errors.full_messages)
              else
                redirect_to back_or_index
              end
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-edit'
        end
      end
    end
  end
end

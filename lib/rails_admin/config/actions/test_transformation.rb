module RailsAdmin
  module Config
    module Actions
      class TestTransformation < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          false
        end

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            data_type = Setup::Model.find(params[:data_type_id]) #.sample_object #rescue params[:sample_data]
            @sample_data = data_type.sample_to_hash

            #@sample_data = JSON.parse(@sample_data) rescue {}

            if transformation = params[:transformation]
              options = {}
              options[:style] = params[:style] if params[:style].present?
              @result = Setup::Flow.transform(transformation, data_type.sample_object, options )
            else
              @result = {}
            end

            #@sample_data = JSON.try(:pretty_generate, @sample_data) || @sample_data
           # @result = JSON.try(:pretty_generate, @result) || @result

            render @action.template_name
          end
        end
      end
    end
  end
end
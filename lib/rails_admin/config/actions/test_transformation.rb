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

            @sample_data = Setup::DataType.find_by(:id => params[:data_type_id]).sample_object rescue params[:sample_data]

            @sample_data = JSON.parse(@sample_data) rescue {}

            if transformation = params[:transformation]
              @result = Setup::Flow.transform(transformation, @sample_data)
            else
              @result = {}
            end

            @sample_data = JSON.pretty_generate(@sample_data)
            @result = JSON.pretty_generate(@result)

            render @action.template_name
          end
        end
      end
    end
  end
end
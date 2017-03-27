module RailsAdmin
  module Config
    module Actions

      class RemoteSharedCollection < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          true
        end

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            operation = Setup::Connection.get("#{Cenit.host}/api/v2/setup/cross_shared_collection")
            parameters = {
              page: params[:page] || 1,
              only: 'id,name,title,readme,shared_version,summary,categories,description,image',
              limit: @limit = 20
            }
            if (@query = params[:query].to_s.presence)
              parameters['$or'] = %w{name title readme summary description}.collect { |field| { field => { '$regex': @query } } }.to_json
            end
            @objects = []
            operation.submit(parameters: parameters) do |response|
              if response.code == 200
                @response = JSON.parse(response.body)
                @objects = @response['cross_shared_collections']
              end
            end
            @model_config = RailsAdmin.config(Setup::CrossSharedCollection)
          end
        end

        register_instance_option :link_icon do
          'fa fa-cube'
        end
      end

    end
  end
end
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
            operation = Setup::Connection.get('http://localhost:3001/api/v2/setup/cross_shared_collection')
            operation.submit(parameters: {
              only: 'id,name,title,readme,shared_version,summary,categories'
            }) do |response|
              if response.code == 200
                @response = JSON.parse(response.body)
                @objects = @response['cross_shared_collections']
              end
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-cube'
        end
      end

    end
  end
end
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
            cenit_host = Cenit.host
            @model_config = RailsAdmin.config(Setup::CrossSharedCollection)
            cenit_api_path = "#{cenit_host}/api/v2/setup/cross_shared_collection"
            fields = 'id,name,title,readme,shared_version,summary,categories,description,image'
            parameters = {
              installed: true,
              page: params[:page] || 1,
              limit: @limit = 20
            }
            if (id = params[:id].presence)
              cenit_api_path = "#{cenit_api_path}/#{id}"
              fields = "#{fields},data"
            elsif (@query = params[:query].to_s.presence)
              parameters['$or'] = %w{name title readme summary description}.collect do |field|
                { field => { '$regex': @query } }
              end.to_json
            end
            parameters.merge!(only: fields)
            operation = Setup::Connection.get(cenit_api_path)
            if (response = operation.submit(parameters: parameters, verbose_response: true)[:http_response])
              @response = JSON.parse(response.body)
              if id
                if response.code == 200
                  @object = Setup::CrossSharedCollection.new_from_json(@response)
                  render :show
                else
                  if response.code == 402
                    flash[:error] = t('admin.flash.object_not_found', model: @model_config.label, id: id)
                  else
                    flash[:error] = t("Unable to retrieve #{@model_config.label} with ID #{id}")
                    redirect_to remote_shared_collection_path
                  end
                end
              else
                if response.code == 200
                  @objects = @response['cross_shared_collections']
                else
                  flash[:error] = "Unable to retrieve #{@model_config.label_plural} from #{cenit_host}"
                  redirect_to dashboard_path
                end
              end
            else
              flash[:error] = "Unable to retrieve #{@model_config.label_plural} from #{cenit_host}"
              redirect_to dashboard_path
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
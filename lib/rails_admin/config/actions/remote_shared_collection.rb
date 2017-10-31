module RailsAdmin
  module Config
    module Actions

      class RemoteSharedCollection < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          authorized? && Cenit.host != Cenit.homepage
        end

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
            @dashboard_group_ref = 'integrations'
            if Cenit.host == Cenit.homepage
              flash[:warning] = t('admin.actions.remote_shared_collection.already_at_host', host: Cenit.host)
              flash[:error] = t('admin.actions.remote_shared_collection.configure_host_option')
              redirect_to dashboard_path
            else
              @model_config = RailsAdmin.config(Setup::CrossSharedCollection)
              cenit_api_path = "#{Cenit.host}/api/v2/setup/cross_shared_collection"
              fields = 'id,name,title,shared_version,summary,categories,description,image,pull_count'
              parameters = {
                installed: true,
                page: params[:page] || 1,
                limit: @limit = 20
              }
              pull = request.path.end_with?('/pull') || params[:pull].to_b
              if (id = params[:id].presence)
                cenit_api_path = "#{cenit_api_path}/#{id}"
                fields = "#{fields},data" unless params[:no_details].to_b
                if pull
                  fields = "#{fields},authors,email,pull_asynchronous,readme,pull_parameters,label,type,many,required,description,properties_locations,property_name,location"
                end
              elsif (@query = params[:query].to_s.presence)
                parameters['$or'] = %w{name title readme summary description}.collect do |field|
                  { field => { '$regex': @query } }
                end.to_json
              end
              parameters.merge!(only: fields)
              operation = Setup::Connection.get(cenit_api_path)
              if (response = operation.submit(parameters: parameters, verbose_response: true)[:response])
                @response = JSON.parse(response.body)
                if id
                  if response.code == 200
                    if pull
                      @response.delete('id')
                      @response.delete('pull_count')
                      new_name = @response['name']
                      i = 0
                      while Setup::CrossSharedCollection.where(name: new_name).exists?
                        i += 1
                        new_name = "#{@response['name']}_remote_pull_#{i}"
                      end
                      if i > 0
                        flash[:warning] = t('admin.actions.remote_shared_collection.pull_rename', model: @model_config.label, name: @response['name'], new_name: new_name)
                        @response['name'] = new_name
                      end
                      shared_collection = Setup::CrossSharedCollection.create_from_json(@response)
                      if shared_collection.errors.blank?
                        msg = t('admin.actions.remote_shared_collection.successful_pull', object_label: obj2msg(shared_collection))
                        msg += '<br><br>'
                        msg += t('admin.actions.remote_shared_collection.try_install', object_label: obj2msg(shared_collection, action: :pull, action_label: t('admin.actions.remote_shared_collection.click_to_install')))
                        flash[:success] = msg.html_safe
                      else
                        do_flash_now(:error, t('admin.actions.remote_shared_collection.error_creating_local', model: @model_config.label), shared_collection.errors.full_messages)
                      end
                      redirect_to shared_collection_index_path
                    else
                      @object = Setup::CrossSharedCollection.new_from_json(@response)
                      render :remote_shared_collection_show
                    end
                  else
                    if response.code == 402
                      flash[:error] = t('admin.flash.object_not_found', model: @model_config.label, id: id)
                    else
                      flash[:error] = t('admin.actions.remote_shared_collection.unable_id_retrieve', model: @model_config.label, id: id)
                      redirect_to remote_shared_collection_path
                    end
                  end
                else
                  if response.code == 200
                    @objects = @response['cross_shared_collections']
                  else
                    flash[:error] = t('admin.actions.remote_shared_collection.unable_host_retrieve', model_plural: @model_config.label_plural, host: Cenit.host)
                    redirect_to dashboard_path
                  end
                end
              else
                flash[:error] = t('admin.actions.remote_shared_collection.unable_host_retrieve', model_plural: @model_config.label_plural, host: Cenit.host)
                redirect_to dashboard_path
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
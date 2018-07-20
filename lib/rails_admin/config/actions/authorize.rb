module RailsAdmin
  module Config
    module Actions

      class Authorize < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Authorization.class_hierarchy
        end


        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do

            errors = nil
            if @object.check
              case @object
              when Setup::BaseOauthAuthorization
                begin
                  cenit_token = OauthAuthorizationToken.create(authorization: @object, data: {})
                  url = @object.authorize_url(cenit_token: cenit_token)
                  cenit_token.save
                  session[:oauth_state] = cenit_token.token

                  redirect_to url
                rescue Exception => ex
                  errors = [ex.message]
                end
              else
                redirect_to rails_admin.edit_path(model_name: @object.class.to_s.underscore.gsub('/', '~'), id: @object.id.to_s)
              end
            else
              errors = @object.errors.full_messages
            end

            if errors
              do_flash(:error, 'Unable to authorize', errors)
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'icon-check'
        end

        register_instance_option :pjax? do
          false
        end
      end

    end
  end
end
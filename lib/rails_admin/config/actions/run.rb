module RailsAdmin
  module Config
    module Actions
      class Run < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [Script, Setup::Algorithm]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:post, :get]
        end

        register_instance_option :controller do
          proc do

            if (@object.parameters.empty? && !@object.try(:need_run_confirmation)) || params[:_run]
              begin
                @output = @object.run(@input = params.delete(:input))
              rescue Exception => ex
                @error = ex.message
              end
            end
            render :run
          end
        end

        register_instance_option :link_icon do
          'icon-play'
        end

        register_instance_option :pjax do
          false
        end
      end
    end
  end
end
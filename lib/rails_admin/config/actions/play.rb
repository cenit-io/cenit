module RailsAdmin
  module Config
    module Actions
      class Play < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          false
        end

        register_instance_option :only do
          Setup::Application
        end

        register_instance_option :visible do
          authorized? && Play.playable?(bindings[:object])
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            if (uri = Play.play_uri(@object))
              redirect_to uri
            else
              flash[:error] = 'Illegal action'
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'icon-play-circle'
        end


        class << self

          def playable?(obj)
            case obj
            when Setup::Application
              obj.actions.any? { |a| a.method == :get && a.match?('/') }
            else
              false
            end
          end

          def play_uri(obj)
            case obj
            when Setup::Application
              "/app/#{obj.ns_slug}/#{obj.slug}"
            else
              nil
            end
          end
        end
      end
    end
  end
end

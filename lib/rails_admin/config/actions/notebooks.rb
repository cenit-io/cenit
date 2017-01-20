module RailsAdmin
  module Config
    module Actions
      class Notebooks < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :link_icon do
          'fa fa-book'
        end

        register_instance_option :controller do
          proc do
            begin
              @gist = notebook_find_or_create
            rescue Exception => ex
              do_flash :error, 'Notebooks:', ex.message
            end
          end
        end
      end

    end
  end
end

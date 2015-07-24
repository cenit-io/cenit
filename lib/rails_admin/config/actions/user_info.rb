module RailsAdmin
  module Config
    module Actions
      class UserInfo < RailsAdmin::Config::Actions::Base

        register_instance_option :root? do
          true
        end

        register_instance_option :breadcrumb_parent do
          nil
        end

        register_instance_option :link_icon do
          'icon-info-sign'
        end
      end
    end
  end
end

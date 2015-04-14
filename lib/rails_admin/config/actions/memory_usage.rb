
module RailsAdmin
  module Config
    module Actions
      class MemoryUsage < RailsAdmin::Config::Actions::Base

        register_instance_option :root? do
          true
        end

        register_instance_option :breadcrumb_parent do
          nil
        end

        register_instance_option :controller do
          proc do
            @objects ||= list_entries(RailsAdmin::Config.model(Setup::Model))

            @max = Setup::Model.fields[:used_memory.to_s].type.new(Setup::Model.max(:used_memory) || 0)
          end
        end

        register_instance_option :link_icon do
          'icon-fire'
        end
      end
    end
  end
end

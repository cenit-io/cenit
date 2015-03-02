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
            @max = 0
            @count = {}
            Setup::DataType.all.each do |data_type|
              @count[data_type.id.to_s] = count = data_type.loaded? ? data_type.records_model.collection_size(1) : 0
              @max = count if count > @max
            end
          end
        end

        register_instance_option :link_icon do
          'icon-fire'
        end
      end
    end
  end
end

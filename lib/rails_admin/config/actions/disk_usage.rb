module RailsAdmin
  module Config
    module Actions
      class DiskUsage < RailsAdmin::Config::Actions::Base

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
              @count[data_type.id.to_s] = count = data_type.records_model.collection_size
              @max = count if count > @max
            end

          end
        end

        register_instance_option :link_icon do
          'icon-hdd'
        end
      end
    end
  end
end

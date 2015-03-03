require 'objspace'

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
              @count[data_type.id.to_s] = count = data_type.loaded? ? MemoryUsage.of(data_type.records_model) : 0
              @max = count if count > @max
            end
          end
        end

        register_instance_option :link_icon do
          'icon-fire'
        end

        class << self

          def of(model)
            size = ObjectSpace.memsize_of(model)
            model.constants(false).each { |c| size += of(c) } if model.is_a?(Class) || model.is_a?(Module)
            size
          end
        end
      end
    end
  end
end

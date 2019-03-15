module RailsAdmin
  module Config
    module Actions

      class ShowRecords < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::AlgorithmOutput
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do
            redirect_to rails_admin.index_path(model_name: @object.data_type.records_model.to_s.underscore.gsub('/', '~'),
                                               algorithm_output: @object.id.to_s)
          end
        end

        register_instance_option :link_icon do
          'icon-list'
        end
      end

    end
  end
end
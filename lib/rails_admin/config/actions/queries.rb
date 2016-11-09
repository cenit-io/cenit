module RailsAdmin
  module Config
    module Actions
      class Queries < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            model = abstract_model.model rescue nil
            model_name = model.name
            @model_name = model.to_s.underscore.gsub('/', '~')
            @queries = []
            if model_name.start_with? 'Dt'
              @queries = Setup::Query.where(data_type: model.data_type)
            elsif (split = model_name.split('Setup::')).size > 1
              @queries = Setup::Query.all.select { |query| query.data_type.name == split[1] }
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-filter'
        end
      end
    end
  end
end

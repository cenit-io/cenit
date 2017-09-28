module RailsAdmin
  module Config
    module Fields
      module Types
        class Scheduler < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :html_attributes do
            {
            }
          end

          register_instance_option :partial do
            :form_scheduler
          end

          register_instance_option :index_pretty_value do
            value
          end

          register_instance_option :pretty_value do
            #TODO Implement this to describe the scheduler in natural language
            if value
              value
            end
          end

          def parse_input(params)
            if params[name].is_a?(Hash) && !params[name].empty?
            end
          end
        end
      end
    end
  end
end

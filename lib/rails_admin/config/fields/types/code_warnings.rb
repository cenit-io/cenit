module RailsAdmin
  module Config
    module Fields
      module Types
        class CodeWarnings < RailsAdmin::Config::Fields::Base

          register_instance_option :read_only do
            true
          end

          register_instance_option :help do
            ''
          end

          register_instance_option :formatted_value do
            bindings[:view].render partial: 'code_warnings'
          end
        end
      end
    end
  end
end

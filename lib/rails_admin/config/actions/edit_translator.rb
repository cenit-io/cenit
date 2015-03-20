module RailsAdmin
  module Config
    module Actions
      class EditTranslator < RailsAdmin::Config::Actions::Edit

        register_instance_option :only do
          Setup::Translator
        end

      end
    end
  end
end

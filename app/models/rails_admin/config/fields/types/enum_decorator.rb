module RailsAdmin
  module Config
    module Fields
      module Types
        Enum.class_eval do

          register_instance_option :enum_for_select do
            enum
          end

          register_instance_option :filter_enum_method do
            @filter_enum_method ||= bindings[:object].class.respond_to?("#{name}_filter_enum") || bindings[:object].respond_to?("#{name}_filter_enum") ? "#{name}_filter_enum" : ''
          end

          register_instance_option :filter_enum do
            if (obj = bindings[:object].class).respond_to?(filter_enum_method)
              obj.send(filter_enum_method)
            elsif (obj = bindings[:object]).respond_to?(filter_enum_method)
              obj.send(filter_enum_method)
            else
              enum
            end
          end
        end
      end
    end
  end
end

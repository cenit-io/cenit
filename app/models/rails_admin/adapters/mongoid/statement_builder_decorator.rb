require 'rails_admin/adapters/mongoid'

module RailsAdmin
  module Adapters
    module Mongoid
      StatementBuilder.class_eval do

        def build_statement_for_type
          case @type
          when :boolean
            build_statement_for_boolean
          when :integer, :decimal, :float
            build_statement_for_integer_decimal_or_float
          when :string, :text, :enum_edit # is convenient to search enum_edit fields as strings
            build_statement_for_string_or_text
          when :enum
            build_statement_for_enum
          when :belongs_to_association, :bson_object_id
            build_statement_for_belongs_to_association_or_bson_object_id
          else
            begin
              if RailsAdmin::Config::Fields::Types.load(@type) < RailsAdmin::Config::Fields::Types::Text
                build_statement_for_string_or_text
              else
                nil # TODO Build statements for other custom rails_admin types
              end
            rescue
              nil
            end
          end
        end
      end
    end
  end
end

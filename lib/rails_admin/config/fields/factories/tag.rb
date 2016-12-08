require 'rails_admin/config/fields'
require 'rails_admin/config/fields/types/tag'


RailsAdmin::Config::Fields.register_factory do |parent, properties, fields|
  model = parent.abstract_model.model
  method_name = "#{properties.name}_values"

  if !Object.respond_to?(method_name) && \
     (model.respond_to?(method_name) || \
         model.method_defined?(method_name))
    fields << RailsAdmin::Config::Fields::Types::Tag.new(parent, properties.name, properties)
    true
  else
    false
  end
end

require 'nested_form/builder_mixin.rb'

module NestedForm
  module BuilderMixin
    def link_to_add(*args, &block)
      options = args.extract_options!.symbolize_keys
      association = args.pop

      unless object.respond_to?("#{association}_attributes=")
        raise ArgumentError, "Invalid association. Make sure that accepts_nested_attributes_for is used for #{association.inspect} association."
      end

      model_object = options.delete(:model_object) do
        #Patch
        reflection = object.try(:reflect_on_association, association) ||
                     object.class.reflect_on_association(association)
        obj = reflection.klass.new
        obj.instance_variable_set(:@_nested_form_dummy_object, true)
        obj
      end

      options[:class] = [options[:class], "add_nested_fields"].compact.join(" ")
      options["data-association"] = association
      options["data-blueprint-id"] = fields_blueprint_id = fields_blueprint_id_for(association)
      args << (options.delete(:href) || "javascript:void(0)")
      args << options

      @fields ||= {}
      @template.after_nested_form(fields_blueprint_id) do
        blueprint = { id: fields_blueprint_id, style: 'display: none' }
        block, options = @fields[fields_blueprint_id].values_at(:block, :options)
        options[:child_index] = "new_#{association}"
        blueprint[:"data-blueprint"] = fields_for(association, model_object, options, &block).to_str
        @template.content_tag(:div, nil, blueprint)
      end
      @template.link_to(*args, &block)
    end
  end
end
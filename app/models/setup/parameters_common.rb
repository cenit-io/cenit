module Setup
  module ParametersCommon

    def template_parameters_hash
      hash = {}
      template_parameters.each { |p| hash[p.key] = p.value }
      try(:inject_other_template_parameters, hash)
      hash
    end

    def conformed_parameters(options = {})
      conforms(:parameters, options)
    end

    def conformed_headers(options = {})
      conforms(:headers, options)
    end

    protected

    def conform_field_value(field, options = {})
      unless template = instance_variable_get(var = "@#{field}_template")
        instance_variable_set(var, template = Liquid::Template.parse(send(field)))
      end
      template.render(options.reverse_merge(template_parameters_hash))
    end

    def conforms(field, options = {})
      unless templates = instance_variable_get(var = "@_#{field}_templates".to_sym)
        templates = {}
        send(field).each { |p| templates[p.key] = Liquid::Template.parse(p.value) }
        try("other_#{field}_each".to_sym) { |key, value| templates[key] = Liquid::Template.parse(value) }
        instance_variable_set(var, templates)
      end
      hash = {}
      templates.each { |key, template| hash[key] = template.render(options.reverse_merge(template_parameters_hash)) }
      hash
    end
  end
end
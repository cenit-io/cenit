module Setup
  module ParametersCommon

    def template_parameters_hash
      hash = {}
      template_parameters.each { |p| hash[p.key] = p.value }
      try(:inject_template_parameters, hash)
      hash
    end

    def conformed_parameters(template_parameters = {})
      conforms(:parameters, template_parameters)
    end

    def conformed_headers(template_parameters = {})
      conforms(:headers, template_parameters)
    end

    protected

    def conform_field_value(field, template_parameters = {})
      unless template = instance_variable_get(var = "@#{field}_template")
        instance_variable_set(var, template = Liquid::Template.parse(send(field)))
      end
      template.render(template_parameters.reverse_merge(template_parameters_hash))
    end

    def conforms(field, template_parameters = {})
      unless templates = instance_variable_get(var = "@_#{field}_templates".to_sym)
        templates = {}
        send(field).each { |p| templates[p.key] = Liquid::Template.parse(p.value) }
        try("other_#{field}_each".to_sym, template_parameters) { |key, value| templates[key] = Liquid::Template.parse(value) }
        instance_variable_set(var, templates)
      end
      hash = {}
      templates.each { |key, template| hash[key] = template.render(template_parameters.reverse_merge(template_parameters_hash)) }
      hash
    end
  end
end
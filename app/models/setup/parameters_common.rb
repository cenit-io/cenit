module Setup
  module ParametersCommon

    def template_parameters_hash
      hash = {}
      template_parameters.each { |p| hash[p.key] = p.value }
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
      template.render(options.merge(template_parameters_hash))
    end

    def conforms(field, options = {})
      unless templates = instance_variable_get(var = "@_#{field}_templates".to_sym)
        templates = {}
        send(field).each { |p| templates[p.key] = Liquid::Template.parse(p.value) }
        instance_variable_set(var, templates)
      end
      hash = {}
      send(field).each { |p| hash[p.key] = templates[p.key].render(options.merge(template_parameters_hash)) }
      hash
    end

  end
end
module Setup
  module WithTemplateParameters

    def template_parameters_hash
      hash = {}
      template_parameters.each { |p| hash[p.key] = p.value }
      try(:inject_template_parameters, hash)
      hash
    end

    def method_missing(symbol, *args)
      if (str = symbol.to_s).start_with?(METHOD_MISSING_PREFIX)
        conforms(str.from(METHOD_MISSING_PREFIX.length), *args)
      else
        super
      end
    end

    protected

    METHOD_MISSING_PREFIX = 'conformed_'

    def conform_field_value(field, template_parameters = {})
      template = instance_variable_get(var = "@#{field}_template")
      unless template
        instance_variable_set(var, template = Liquid::Template.parse(send(field)))
      end
      template.render(template_parameters.reverse_merge(template_parameters_hash))
    end

    def conforms(field, template_parameters = {}, base_hash = nil)
      templates = instance_variable_get(var = "@_#{field}_templates".to_sym)
      unless templates
        templates = {}
        send(field).each { |p| templates[p.key] = Liquid::Template.parse(p.value.to_s) }
        try("other_#{field}_each".to_sym, template_parameters) { |key, value| templates[key] = value && Liquid::Template.parse(value) }
        instance_variable_set(var, templates)
      end
      hash = base_hash || {}
      templates.each { |key, template| hash[key] = template && template.render(template_parameters.reverse_merge(template_parameters_hash)) }
      hash
    end

  end
end

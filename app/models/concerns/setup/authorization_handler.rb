module Setup
  module AuthorizationHandler
    extend ActiveSupport::Concern

    included do
      binding_belongs_to :authorization, class_name: Setup::Authorization.to_s, inverse_of: nil
      field :authorization_handler, type: Boolean

      before_save :check_authorization
    end

    def using_authorization
      @auth || authorization
    end

    def check_authorization
      if using_authorization.present?
        field = authorization_handler ? :template_parameters : :headers
        auth_params = using_authorization.class.send("auth_#{field}")
        conflicting_keys = send(field).select { |p| auth_params.key?(p.key) }.collect(&:key)
        if conflicting_keys.present?
          label = 'authorization ' + field.to_s.tr('_', ' ')
          errors.add(:base, "#{label.capitalize} conflicts while authorization handler is #{authorization_handler ? '' : 'not'} checked")
          errors.add(field, "contains #{label} keys: #{conflicting_keys.to_sentence}")
          send(field).any_in(key: conflicting_keys).each { |p| p.errors.add(:key, "conflicts with #{label}") }
        end
      end
      abort_if_has_errors
    end

    def other_headers_each(template_parameters, &block)
      using_authorization.each_header(template_parameters, &block) if using_authorization && !authorization_handler && block
    end

    def inject_other_parameters(hash, template_parameters)
      using_authorization.each_parameter(template_parameters) do |key, value|
        hash[key] = value unless hash.key?(key)
      end if using_authorization
    end

    def inject_template_parameters(hash)
      using_authorization.each_template_parameter do |key, value|
        hash[key] = value unless hash.key?(key) && authorization_handler
      end if using_authorization
    end

    def with(options)
      if options.is_a?(Setup::Authorization)
        @auth = options
        self
      else
        super
      end
    end
  end
end

module Setup
  module AuthorizationHandler
    extend ActiveSupport::Concern

    included do

      belongs_to :authorization, class_name: Setup::Authorization.to_s, inverse_of: nil
      field :authorization_handler, type: Boolean

      before_save :check_authorization
    end

    def check_authorization
      if authorization.present?
        field = authorization_handler ? :template_parameters : :headers
        auth_params = authorization.class.send("auth_#{field}")
        conflicting_keys = send(field).select { |p| auth_params.has_key?(p.key) }.collect(&:key)
        if conflicting_keys.present?
          label = 'authorization ' + field.to_s.gsub('_', ' ')
          errors.add(:base, "#{label.capitalize} conflicts while authorization handler is #{authorization_handler ? '' : 'not'} checked")
          errors.add(field, "contains #{label} keys: #{conflicting_keys.to_sentence}")
          send(field).any_in(key: conflicting_keys).each { |p| p.errors.add(:key, "conflicts with #{label}") }
        end
      end
      errors.blank?
    end

    def other_headers_each(&block)
      authorization.each_header(&block) if authorization && !authorization_handler && block
    end

    def inject_other_template_parameters(hash)
      authorization.each_template_parameter do |key, value|
        hash[key] = value unless hash.has_key?(key) && authorization_handler
      end if authorization
    end
  end
end

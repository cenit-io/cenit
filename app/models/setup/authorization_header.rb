module Setup
  module AuthorizationHeader
    extend ActiveSupport::Concern

    included do
      auth_headers Authorization: ->(auth, template_parameters) { auth.build_auth_header(template_parameters) }
    end

    def build_auth_header(_template_parameters)
      fail NotImplementedError
    end
  end
end

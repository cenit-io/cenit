module Cenit
  class AuthToken < BasicToken

    token_length 60

    before_save :authorize

    def authorize
      errors.add(:base, 'You are not authorized to create/update Auth Tokens') unless ::User.current_super_admin?
      errors.blank?
    end
  end
end
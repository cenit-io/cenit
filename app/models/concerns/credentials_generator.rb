module CredentialsGenerator
  extend ActiveSupport::Concern

  include ::NumberGenerator
  include ::TokenGenerator


  def regenerate_credentials!
    regenerate_credentials
    save
  end

  def regenerate_credentials
    regenerate_number
    regenerate_token
  end
end

module Setup
  class WalmartAuthorization < Setup::Authorization
    include CenitScoped

    deny :all

    build_in_data_type.with(:namespace, :name).referenced_by(:namespace, :name)

    field :consumerId, type: String
    field :privKey, type: String
    field :marketPlace, type: String

    validates_presence_of :consumerId, :privKey, :marketPlace

    auth_headers 'WM_CONSUMER.ID': :consumerId,
                 'WM_SVC.NAME': :marketPlace,
                 'WM_QOS.CORRELATION_ID': :correlation_method,
                 'WM_SEC.AUTH_SIGNATURE': ->(auth, template_parameters) { auth.sign_data(template_parameters) },
                 'WM_SEC.TIMESTAMP':  -> (auth, template_parameters) { auth.timestamp}

    def timestamp
      @timestamp
    end

    def correlation_method
      Devise.friendly_token
    end

    def sign_data(template_parameters)
      jar = 'tmp/DigitalSignatureUtil-1.0.0.jar'
      path = template_parameters[:url]+template_parameters[:path]
      method =template_parameters[:method].upcase

      result = %x( java -jar #{jar} DigitalSignatureUtil #{path} #{consumerId} #{privKey} #{method} tmp )

      result = result.split('WM_SEC.TIMESTAMP:')
      @timestamp = result[1].chop     #Timestamp
      result[0].split('WM_SEC.AUTH_SIGNATURE:')[1].chop #Signature
    end


    def authorized?
      consumerId.present? && privKey.present? && marketPlace.present?
    end

  end

end

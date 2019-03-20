module Setup
  class AwsAuthorization < Setup::Authorization
    include CenitScoped
    include RailsAdmin::Models::Setup::AwsAuthorizationAdmin

    deny :all

    build_in_data_type.with(:namespace, :name).referenced_by(:namespace, :name)

    field :aws_access_key, type: String
    field :aws_secret_key, type: String
    field :seller, type: String
    field :merchant, type: String
    field :markets, type: String
    field :mws_auth_token, type: String
    field :version, type: String, default: '2011-01-01'
    field :signature_method, type: String, default: 'HmacSHA256'
    field :signature_version, type: String, default: '2'

    validates_presence_of :aws_access_key, :aws_secret_key, :seller, :markets
    validates_inclusion_of :signature_method, in: ->(a) { a.signature_method_enum }
    validates_inclusion_of :signature_version, in: ->(a) { a.signature_version_enum }

    auth_headers 'Content-MD5': ->(auth, template_parameters) { auth.body_do_sign(template_parameters[:body]) }

    auth_parameters Timestamp: ->(auth, template_parameters) { auth.timestamp },
                    SignatureMethod: :signature_method,
                    SignatureVersion: :signature_version,
                    AWSAccessKeyId: :aws_access_key,
                    SellerId: ->(auth, template_parameters) { auth.seller_id },
                    Marketplace: :markets,
                    Version: :version,
                    MWSAuthToken: :mws_auth_token,
                    Signature: ->(auth, template_parameters) { auth.do_sign(template_parameters) }

    auth_template_parameters aws_secret_key: :aws_secret_key

    def seller_id
      merchant.blank? ? seller : merchant
    end

    def list_pattern
      '%{key}List.%{ext}.%<index>d'
    end

    def signature_method_enum
      %w(HmacSHA256 HmacSHA1)
    end

    def signature_version_enum
      ['2']
    end

    def timestamp
      @timestamp ||= Time.now.iso8601
    end

    def do_sign(template_parameters)
      qp = template_parameters[:query_parameters].symbolize_keys.merge(Timestamp: timestamp,
                                                                       SignatureMethod: signature_method,
                                                                       SignatureVersion: signature_version,
                                                                       AWSAccessKeyId: aws_access_key,
                                                                       SellerId: seller_id,
                                                                       Marketplace: markets,
                                                                       Version: version,
                                                                       MWSAuthToken: mws_auth_token)

      template_parameters = template_parameters.merge(query_parameters: qp)
      self.class.do_sign(template_parameters)
    end

    def body_do_sign(body)
      Digest::MD5.base64digest(body).strip if body
    end

    class << self
      def do_sign(template_parameters)
        template_parameters = template_parameters.with_indifferent_access
        digest = OpenSSL::Digest::SHA256.new
        message = [
          template_parameters[:method].to_s.upcase,
          template_parameters[:url].to_s.downcase,
          template_parameters[:path].to_s.downcase,
          params(template_parameters)].join "\n"
        uri_escape Base64.encode64(OpenSSL::HMAC.digest(digest, template_parameters[:aws_secret_key], message)).chomp
      end

      def params(template_parameters)
        template_parameters[:query_parameters].each { |_, value| value = normalize_val(value) }.sort
        template_parameters[:query_parameters].to_param
      end

      def uri_escape(value)
        value.gsub /([^a-zA-Z0-9_.~-]+)/ do
          '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
        end
      end

      def normalize_val(value)
        uri_escape(value.respond_to?(:iso8601) ? value.iso8601 : value.to_s)
      end

    end

  end
end

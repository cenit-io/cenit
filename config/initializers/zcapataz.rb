require 'capataz/capataz'

Capataz.config do

  deny_declarations_of :module, :class, :yield, :self, :def, :const, :ivar, :cvar, :gvar, :return

  deny_invoke_of :require, :new, :create, :class, :eval, :class_eval, :instance_eval, :instance_variable_set, :instance_variable_get, :constants, :const_get, :const_set, :constantize

  allowed_constants Psych, JSON, Array, Hash, Nokogiri, Nokogiri::XML, Time, Base64, Digest, Digest::MD5, SecureRandom, Setup, Setup::Library, Setup::Schema, Setup::SchemaDataType, OpenSSL, OpenSSL::Digest, OpenSSL::HMAC

  allow_on JSON, [:parse, :pretty_generate]

  allow_on Psych, [:load, :add_domain_type]

  allow_for ActionView::Base, []

  allow_for Setup::DataType, ((%w(_json _xml _edi) + ['']).collect do |format|
    %w(create new create!).collect do |action|
      if action.end_with?('!')
        "#{action.chop}_from#{format}!"
      else
        "#{action}_from#{format}"
      end
    end + [:create_from]
  end + [:name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model]).flatten

  allow_for [Class, Mongoff::Model], [:where, :all, :new_sign, :digest, :now]

  allow_for [Mongoid::Criteria, Mongoff::Criteria], Enumerable.instance_methods(false) + Origin::Queryable.instance_methods(false)

  deny_for [Setup::DynamicRecord, Mongoff::Record], ->(instance, method) do
    return false if [:id, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :[], :[]=].include?(method)
    return false if [:data].include?(method) && instance.is_a?(Mongoff::GridFs::FileFormatter)
    if (method = method.to_s).end_with?('=')
      method = method.chop
    end
    instance.orm_model.property_schema(method).nil?
  end
end
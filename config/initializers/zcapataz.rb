require 'capataz/capataz'

Capataz.config do

  deny_declarations_of :module, :class, :yield, :self, :def, :const, :ivar, :cvar, :gvar, :return

  deny_invoke_of :require, :new, :create, :class, :eval, :class_eval, :instance_eval, :instance_variable_set, :instance_variable_get, :constants, :const_get, :const_set, :constantize

  allowed_constants Psych, JSON, URI, File, Array, Hash, Nokogiri, Nokogiri::XML, Time, Base64, Digest, Digest::MD5,
                    SecureRandom, Setup, Setup::DataType, Setup::Library, Setup::Schema, Setup::SchemaDataType, OpenSSL,
                    OpenSSL::Digest, OpenSSL::HMAC

  allow_on JSON, [:parse, :pretty_generate]

  allow_on Psych, [:load, :add_domain_type]

  allow_on YAML, [:load, :add_domain_type]

  allow_on URI, [:decode, :encode]

  allow_on File, [:dirname, :basename]

  allow_on RamlParser::Parser, [:parse_hash, :parse_doc]

  allow_for ActionView::Base, []

  allow_for [Mongoff::Model], [:where, :all]

  allow_for [Setup::Raml],  [:id, :name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model, :ref_hash, :raml_parse, :build_hash, :map_collection]

  allow_for [Class], [:where, :all, :new_sign, :digest, :hexdigest, :id]

  allow_for [Mongoid::Criteria, Mongoff::Criteria], Enumerable.instance_methods(false) + Origin::Queryable.instance_methods(false)

  allow_for Setup::Task, [:state, :resume_in, :run_again, :progress, :progress=, :update]

  allow_for Setup::DataType, ((%w(_json _xml _edi) + ['']).collect do |format|
                             %w(create new create!).collect do |action|
                               if action.end_with?('!')
                                 "#{action.chop}_from#{format}!"
                               else
                                 "#{action}_from#{format}"
                               end
                             end + [:create_from]
                           end + [:name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model]).flatten

  allow_for [Class], [:where, :all, :new_sign, :digest, :now]

  deny_for [Setup::DynamicRecord, Mongoff::Record], ->(instance, method) do
    return false if [:id, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :[], :[]=, :save, :all, :where, :records_model, :nil?, :==, :errors].include?(method)
    return false if [:data].include?(method) && instance.is_a?(Mongoff::GridFs::FileFormatter)
    if (method = method.to_s).end_with?('=')
      method = method.chop
    end
    instance.orm_model.property_schema(method).nil?
  end
end
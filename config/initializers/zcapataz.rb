require 'capataz/capataz'

Capataz.config do

  deny_declarations_of :module, :class, :yield, :self, :def, :const, :ivar, :cvar, :gvar, :return

  deny_invoke_of :require, :new, :create, :class, :eval, :class_eval, :instance_eval, :instance_variable_set, :instance_variable_get, :constants, :const_get, :const_set, :constantize

  allowed_constants Psych, JSON, URI, File, Array, Hash, Nokogiri, Nokogiri::XML, Time, Base64, Digest, Digest::MD5,
                    SecureRandom, Setup, Setup::DataType, Setup::Library, Setup::Schema, Setup::SchemaDataType, OpenSSL,
                    OpenSSL::Digest, OpenSSL::HMAC, Setup::Task, Setup::Task::RUNNING_STATUS, Setup::Task::NOT_RUNNING_STATUS,
                    Setup::Webhook

  allow_on JSON, [:parse, :pretty_generate]

  allow_on Psych, [:load, :add_domain_type]

  allow_on YAML, [:load, :add_domain_type]

  allow_on URI, [:decode, :encode]

  allow_on File, [:dirname, :basename]

  allow_on RamlParser::Parser, [:parse_hash, :parse_doc]

  allow_for ActionView::Base, [:escape_javascript, :j]

  allow_on Setup::Task::RUNNING_STATUS, [:include?]

  allow_on Setup::Task::NOT_RUNNING_STATUS, [:include?]

  allow_for [Mongoff::Model], [:where, :all, :data_type]

  allow_for [Setup::Raml],  [:id, :name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model, :ref_hash, :raml_parse, :build_hash, :map_collection]

  allow_for [Class], [:where, :all, :new_sign, :digest, :hexdigest, :id]

  allow_for [Mongoid::Criteria, Mongoff::Criteria], Enumerable.instance_methods(false) + Origin::Queryable.instance_methods(false) + [:each, :present?, :blank?]

  allow_for Setup::Task, [:status, :scheduler, :state, :resume_in, :run_again, :progress, :progress=, :update, :destroy, :notifications]

  allow_for Setup::Scheduler, [:activated?]

  allow_for Setup::Webhook::ResponseProxy, [:code, :body, :headers]

  allow_for Setup::DataType, ((%w(_json _xml _edi) + ['']).collect do |format|
                             %w(create new create!).collect do |action|
                               if action.end_with?('!')
                                 "#{action.chop}_from#{format}!"
                               else
                                 "#{action}_from#{format}"
                               end
                             end + [:create_from]
                           end + [:name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :records_model, :library, :library_id]).flatten

  allow_for [Class], [:where, :all, :new_sign, :digest, :now, :data_type]

  deny_for [Setup::DynamicRecord, Mongoff::Record], ->(instance, method) do
    return false if [:id, :to_json, :to_edi, :to_hash, :to_xml, :to_xml_element, :to_params, :[], :[]=, :save, :all, :where, :orm_model, :nil?, :==, :errors].include?(method)
    return false if [:data].include?(method) && instance.is_a?(Mongoff::GridFs::FileFormatter)
    if (method = method.to_s).end_with?('=')
      method = method.chop
    end
    instance.orm_model.property_schema(method).nil?
  end
end
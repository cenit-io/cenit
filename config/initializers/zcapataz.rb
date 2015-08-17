require 'capataz/capataz'

Capataz.config do

  deny_declarations_of :module, :class, :yield, :self, :def, :const, :ivar, :cvar, :gvar, :return

  deny_invoke_of :require, :new, :create, :class, :eval, :class_eval, :instance_eval, :instance_variable_set, :instance_variable_get, :constants, :const_get, :const_set, :constantize

  allowed_constants JSON, Array, Hash, Nokogiri, Nokogiri::XML

  allow_on JSON, :parse

  allow_for ActionView::Base, []

  allow_for Setup::Model, (%w(json xml edi).collect do |format|
    %w(create new create!).collect do |action|
      if action.end_with?('!')
        "#{action.chop}_from_#{format}!"
      else
        "#{action}_from_#{format}"
      end
    end + [:create_from]
  end + [:name, :slug, :to_json, :to_edi, :to_hash, :to_xml, :to_params]).flatten

  deny_for [Setup::DynamicModel, Mongoff::Record], ->(instance, method) do
    return false if [:id, :to_json, :to_edi, :to_hash, :to_xml, :to_params, :[], :[]=].include?(method)
    return false if [:data].include?(method) && instance.is_a?(Mongoff::GridFs::FileFormatter)
    if (method = method.to_s).end_with?('=')
      method = method.chop
    end
    instance.orm_model.property_schema(method).nil?
  end
end
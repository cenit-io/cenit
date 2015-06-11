
require 'capataz/capataz'

Capataz.config do

  deny_declarations_of :module, :class, :yield, :self, :def, :const, :ivar, :cvar, :gvar

  deny_invoke_of :require, :new, :create, :class, :eval, :class_eval, :instance_eval, :instance_variable_set, :instance_variable_get, :constants, :const_get, :const_set, :constantize

  allowed_constants JSON

  allow_on JSON, :parse

  allow_for ActionView::Base, :render

  deny_for [Mongoid::CenitExtension, Mongoff::Record], ->(instance, method) do
    return false if [:to_json, :to_edi, :to_hash, :to_xml].include?(method)
    if (method = method.to_s).end_with?('=')
      method = method.chop
    end
    instance.orm_model.property_schema(method).nil?
  end
end
module Setup
  module SnippetCode
    extend ActiveSupport::Concern

    include ShareWithBindings

    included do

      binding_belongs_to :snippet, class_name: Setup::Snippet.to_s, inverse_of: nil

      before_save do
        if snippet_required?
          configure_snippet
          if snippet_ref.changed? && !snippet_ref.save
            snippet_ref.errors.full_messages.each do |msg|
              errors.add(:code, msg)
            end
          end
        end
        errors.blank?
      end
    end

    # TODO Remove when refactoring translators and included only on code required models
    def snippet_required?
      true
    end

    def configure_snippet
      if snippet_ref.new_record?
        snippet_ref.namespace = namespace
        name = snippet_name
        i = 0
        while Setup::Snippet.where(namespace: namespace, name: name).exists?
          name = snippet_name("(#{i += 1})")
        end
        snippet_ref.name = name
      elsif snippet_ref.changed_attributes.key?('code') &&
            snippet_ref.tenant != Cenit::MultiTenancy.tenant_model.current
        self.snippet = Setup::Snippet.new(snippet_ref.attributes.reject { |key, _| %w(_id origin).include?(key) })
        name = snippet_ref.name
        i = 0
        while Setup::Snippet.where(namespace: namespace, name: name).exists?
          name = snippet_name("(#{i += 1})")
        end
        snippet_ref.name = name
      end
    end

    def snippet_ref
      self.snippet ||= Setup::Snippet.new
      snippet.instance_variable_set(:@snippet_code_owner, self)
      snippet
    end

    def snippet_name(suffix = '')
      name = code_name
      if (ext = ".#{code_extension.to_s.strip}".squeeze('.')).length > 1
        name = name.to(name.rindex('.') - 1) if name.ends_with?(ext)
      else
        ext = ''
      end
      name + suffix + ext
    end

    def code_name
      name.to_s.to_file_name
    end

    def code_extension
      nil
    end

    def code
      snippet_ref.code
    end

    def code=(code)
      snippet_ref.code = code
    end

    # TODO: Only for legacy codes, remove after migration

    def read_attribute(name)
      if name.to_s == self.class.legacy_code_attribute.to_s
        if respond_to?(name)
          send(name)
        else
          code
        end
      elsif name.to_s == 'code'
        code
      else
        super
      end
    end

    module ClassMethods

      def instantiate(attrs = nil, selected_fields = nil)
        record = super
        if record.snippet.nil? && (legacy_code = record.attributes[legacy_code_attribute])
          if record.respond_to?(assign_legacy_code = "#{legacy_code_attribute}=")
            record.send(assign_legacy_code, legacy_code)
          else
            record.code = legacy_code
          end
        end
        record
      end

      def legacy_code_attribute(*args)
        if args.length == 0
          @legacy_code_attribute
        else
          @legacy_code_attribute = args[0].to_s
        end
      end

    end
  end
end

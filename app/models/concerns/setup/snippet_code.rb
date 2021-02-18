module Setup
  module SnippetCode
    extend ActiveSupport::Concern

    include ShareWithBindings

    included do
      build_in_data_type.and(
        properties: {
          code: {
            type: 'string',
            edi: {
              discard: true
            }
          },
          default_snippet: {
            referenced: true,
            '$ref': {
              namespace: 'Setup',
              name: 'Snippet'
            },
            edi: {
              discard: true
            }
          },
          creator_access: {
            type: 'boolean',
            edi: {
              discard: true
            }
          },
          snippet_ref_binding: {
            referenced: true,
            '$ref': {
              namespace: 'Setup',
              name: 'Binding'
            },
            edi: {
              discard: true
            }
          }
        }
      )

      binding_belongs_to :snippet, class_name: Setup::Snippet.to_s, inverse_of: nil

      trace_ignore :snippet_id

      before_save :check_snippet
    end

    def creator_access
      creator == User.current
    end

    def code_key
      "#{snippet_ref&.code_key}"
    end

    def default_snippet_id
      instance_variable_get(:@_binding_shadow_snippet_id)
    end

    def default_snippet
      @default_snippet ||= Setup::Snippet.where(id: default_snippet_id).first
    end

    def snippet_ref_binding
      instance_variable_get(:@_snippet_id_binding)
    end

    def check_snippet
      if snippet_required?
        configure_snippet
        if snippet_ref.changed? && !snippet_ref.save
          snippet_ref.errors.full_messages.each do |msg|
            errors.add(:code, msg)
          end
        end
        if default_snippet
          self.changed_attributes.delete('snippet_id')
        elsif User.current == creator
          self.changed_attributes['snippet_id'] ||= default_snippet_id
        end
      end
      abort_if_has_errors
    end

    # TODO Remove when refactoring translators and included only on code required models
    def snippet_required?
      true
    end

    def configure_snippet
      if snippet_ref.new_record?
        snippet_ref.namespace = snippet_ref.namespace.presence || namespace
        name = snippet_ref.name.presence || snippet_name
        i = 0
        while Setup::Snippet.where(namespace: snippet_ref.namespace, name: name).exists?
          name = snippet_name("(#{i += 1})")
        end
        snippet_ref.name = name
      elsif snippet_ref.changed_attributes.key?('code') && snippet_ref.origin != :default
        self.snippet = Setup::Snippet.new(snippet_ref.attributes.reject { |key, v| v.nil? || %w(_id origin).include?(key) })
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
      if snippet
        snippet_ref.code
      else
        ''
      end
    end

    def code=(code)
      snippet_ref.code = code
    end

    # TODO: Only for legacy codes, remove after migration

    def read_raw_attribute(name)
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
        if args.length.zero?
          @legacy_code_attribute
        else
          @legacy_code_attribute = args[0].to_s
        end
      end

      def copy_options
        opts = super
        (opts[:ignore] ||= []) << :snippet
        (opts[:including] ||= []) << :code
        opts
      end
    end
  end
end

module Setup
  module SnippetCode
    extend ActiveSupport::Concern

    include ShareWithBindings

    included do

      binding_belongs_to :snippet, class_name: Setup::Snippet.to_s, inverse_of: nil

      before_save do
        if snippet_ref.new_record?
          name = snippet_name
          i = 0
          while Setup::Snippet.where(tenant: Cenit::MultiTenancy.tenant_model.current, name: name).exists?
            name = snippet_name("(#{i += 1})")
          end
          snippet_ref.name = name
        elsif snippet_ref.changed_attributes.has_key?('code') &&
          snippet_ref.tenant != Cenit::MultiTenancy.tenant_model.current
          self.snippet = Setup::Snippet.new(snippet_ref.attributes.reject { |key, _| %w(_id origin).include?(key) })
          name = snippet_ref.name
          i = 0
          while Setup::Snippet.where(tenant: Cenit::MultiTenancy.tenant_model.current, name: name).exists?
            name = snippet_name("(#{i += 1})")
          end
          snippet_ref.name = name
        end
        unless snippet_ref.save
          snippet_ref.errors.full_messages.each do |msg|
            errors.add(:code, msg)
          end
        end
        errors.blank?
      end
    end

    def snippet_ref
      self.snippet ||= Setup::Snippet.new
    end

    def snippet_name(suffix = '')
      name = code_name.to_method_name.underscore
      if (ext = ".#{code_extension.strip}".squeeze('.')).length > 1
        if name.ends_with?(ext)
          name = name.to(name.rindex('.') - 1)
        end
      else
        ext = ''
      end
      name + suffix + ext
    end

    def code_name
      "#{namespace}_#{name}".to_file_name
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
  end
end
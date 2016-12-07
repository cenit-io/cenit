module RailsAdmin
  module Models
    module Setup
      module SnippetAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            weight 430
            object_label_method { :custom_title }

            configure :name
            configure :code, :code do
              code_config do
                {
                  mode: {
                    'auto': 'javascript',
                    'text': 'javascript',
                    'null': 'javascript',
                    'c': 'clike',
                    'cpp': 'clike',
                    'csharp': 'clike',
                    'csv': 'javascript',
                    'fsharp': 'mllike',
                    'java': 'clike',
                    'latex': 'stex',
                    'ocaml': 'mllike',
                    'scala': 'clike',
                    'squirrel': 'clike'
                  }[bindings[:object].type] || bindings[:object].type
                }
              end
            end

            edit do
              field :namespace, :enum_edit
              field :name
              field :type
              field :description
              field :code
            end

            show do
              field :namespace
              field :name
              field :type
              field :description
              field :code
            end

            fields :namespace, :name, :type, :description
          end
        end

      end
    end
  end
end

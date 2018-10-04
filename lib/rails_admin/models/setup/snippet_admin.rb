module RailsAdmin
  module Models
    module Setup
      module SnippetAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            navigation_icon 'fa fa-code'
            weight 430
            object_label_method { :custom_title }

            configure :namespace, :enum_edit
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
              field :namespace
              field :name
              field :type
              field :description
              field :code
            end

            list do
              field :namespace
              field :name
              field :type
              field :description
              field :updated_at
            end

            fields :namespace, :name, :type, :description, :code, :updated_at
          end
        end

      end
    end
  end
end

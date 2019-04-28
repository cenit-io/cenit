module RailsAdmin
  module Config
    module Fields
      module Types
        class AutoComplete < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :html_attributes do
            {
              class: 'auto-complete',
              required: required?,
              cols: '48',
              rows: '3',
              'data-auto-complete-source': source.to_json,
              'data-auto-complete-anchor': anchor
            }
          end

          register_instance_option :source do
            [
              { value: 'support@cenit.io', text: ENV['COMPANY_NAME'] || 'Cenit IO' }
            ]
          end

          register_instance_option :anchor do
            '@'
          end
        end
      end
    end
  end
end

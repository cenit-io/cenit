module RailsAdmin
  module Config
    module Fields
      module Types
        Datetime.class_eval do
          register_instance_option :formatted_value do
            if (time = value)
              if (current_account = Account.current)
                time = time.to_time.localtime(current_account.time_zone_offset)
              end
              I18n.l(time, format: strftime_format)
            else
              ''.html_safe
            end
          end
        end
      end
    end
  end
end

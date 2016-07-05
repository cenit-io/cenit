module RailsAdmin
  module Config
    module Fields
      module Types
        class HtmlErb < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :pretty_value do
            template = value.gsub('&lt;%', '<%').gsub('%&gt;', '%>').gsub('%3C%', '<%').gsub('%%3E', '%>')
            output =
              begin
                Setup::Transformation::ActionViewTransform.run(transformation: template,
                                                               style: 'html.erb',
                                                               base_url: bindings[:controller].request.base_url,
                                                               user_key: User.current_number,
                                                               user_token: User.current_token,
                                                               object: bindings[:object])
              rescue Exception => ex
                nil
              end
            output && output.html_safe
          end

        end
      end
    end
  end
end

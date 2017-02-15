module RailsAdmin
  module Config
    module Fields
      module Types
        class HtmlErb < RailsAdmin::Config::Fields::Types::Code

          register_instance_option :code_config do
            {
              mode: 'text/html'
            }
          end

          register_instance_option :pretty_value do
            template = value.to_s.gsub('&lt;%', '<%').gsub('%&gt;', '%>').gsub('%3C%', '<%').gsub('%%3E', '%>')
            output =
              begin
                Setup::Transformation::ActionViewTransform.run(code: template,
                                                               style: 'html.erb',
                                                               base_url: bindings[:controller].request.base_url,
                                                               user_key: Account.current_key,
                                                               user_token: Account.current_token,
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

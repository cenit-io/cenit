module RailsAdmin
  module Config
    module Fields
      module Types
        class CenitOauthScope < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :html_attributes do
            {
            }
          end

          register_instance_option :partial do
            :form_cenit_oauth_scope
          end

          register_instance_option :index_pretty_value do
            "<div class='scope_at_index'> #{pretty_value} </div>".html_safe
          end

          register_instance_option :pretty_value do
            if value
              (bindings[:view].render partial: 'oauth/description', locals: { scope: value }).html_safe
            end
          end

          register_instance_option :access_tokens do
            Cenit::OauthScope::ACCESS_TOKENS
          end

          register_instance_option :cenit_basic_scopes do
            Cenit::OauthScope::TOKENS
          end


          def cenit_oauth_scope
            Cenit::OauthScope.new(value).access_by_ids
          end

          def each_data_type(cenit_oauth_scope, &block)
            data_types = Hash.new { |h, k| h[k] = [] }
            cenit_oauth_scope.each_criteria do |method, criteria|
              criteria['_id']['$in'].each { |id| data_types[id] << method }
            end
            data_types.each { |dt_id, methods| block.call(dt_id, methods) }
          end

          def parse_input(params)
            if params[name].is_a?(Hash) && !params[name].empty?
              basics = params[name].delete('basic') || []
              if basics.exclude?(Cenit::OauthScope::OPENID_TOKEN) && Cenit::OauthScope::OPENID_TOKENS.any?{ |n| basics.include?(n)}
                basics << Cenit::OauthScope::OPENID_TOKEN
              end
              scope = basics.join(' ')
              methods_hash = Hash.new { |h, k| h[k] = Set.new }
              params[name].each do |data_type_id, methods|
                next unless methods.is_a?(Array)
                methods.each { |method| methods_hash[method] << data_type_id }
              end
              methods_hash.each do |method, data_types_ids|
                q = { _id: { '$in': data_types_ids.to_a } }
                scope = "#{method} #{q.to_json} #{scope}"
              end
              params[name] = scope
            end
          end
        end
      end
    end
  end
end

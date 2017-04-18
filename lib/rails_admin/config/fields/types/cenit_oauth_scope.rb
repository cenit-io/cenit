module RailsAdmin
  module Config
    module Fields
      module Types
        class CenitOauthScope < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :partial do
            :form_cenit_oauth_scope
          end

          register_instance_option :pretty_value do
            value.html_safe if value
          end

          register_instance_option :http_methods do
            %w(get post put delete)
          end

          register_instance_option :cenit_basic_scopes do
            %w(get post put delete) + %w(openid email profile address phone offline_access auth)
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
              scope = (params[name].delete('basic') || []).join(' ')
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

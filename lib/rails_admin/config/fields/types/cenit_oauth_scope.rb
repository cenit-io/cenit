module RailsAdmin
  module Config
    module Fields
      module Types
        class CenitOauthScope < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :partial do
            :form_cenit_oauth_scope
          end

          register_instance_option :pretty_value do
            bindings[:view].link_to(value, value, target: '_blank').html_safe if value
          end

          register_instance_option :http_methods do
            %w(get post put delete)
          end

          def each_data_type(&block)
            data_types = Hash.new { |h, k| h[k] = [] }
            Cenit::OauthScope.new(value).access_by_ids.each_criteria do |method, criteria|
              criteria['_id']['$in'].each { |id| data_types[id] << method }
            end
            data_types.each { |dt_id, methods| block.call(dt_id, methods) }
          end

          def parse_input(params)
            methods_hash = Hash.new { |h, k| h[k] = Set.new }
            params[name].each do |data_type_id, methods|
              next unless methods.is_a?(Array)
              methods.each { |method| methods_hash[method] << data_type_id }
            end
            scope = ''
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

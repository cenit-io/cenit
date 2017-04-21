module RailsAdmin
  module Config
    module Fields
      module Types
        class CenitOauthScope < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :partial do
            :form_cenit_oauth_scope
          end
          register_instance_option :index_pretty_value do
            "<div class='scope_at_index'> #{pretty_value} </div>".html_safe
          end
          register_instance_option :pretty_value do
            if value
              begin
                cenit_oauth_scope = ::Cenit::OauthScope.new(value).access_by_ids
                methods = Hash.new { |h, k| h[k] = [] }
                cenit_oauth_scope.each_criteria do |method, criteria|
                  methods[method] = Setup::DataType.where(criteria)
                end
                basic = Hash.new
                if !cenit_oauth_scope.openid_set.empty?
                  basic['openid']= cenit_oauth_scope.openid_set.to_a
                end
                if !cenit_oauth_scope.super_methods_set.empty?
                  basic['super_methods_set']= cenit_oauth_scope.super_methods_set.to_a
                end
                if !cenit_oauth_scope.auth?
                  basic['auth']= true
                end
                if !cenit_oauth_scope.offline_access?
                  basic['offline_access']= true
                end
                basic = basic.merge(methods)
                html = '<ul>'
                basic.each do |key, value|
                  case key
                  when 'openid'
                    value = value.join(',')
                    html+= "<li>#{value}</li>"
                  when 'super_methods_set'
                    value = value.join(',')
                    html+= "<li>#{value}</li>"
                  else
                    if value == true
                      html+= "<li>#{key}</li>"
                    else
                      next unless (count = value.count) > 0
                      max_data_type_to_show = 3
                      config = RailsAdmin.config(::Setup::DataType)
                      am = config.abstract_model
                      v = bindings[:view]
                      if count > max_data_type_to_show
                        i = 0
                        first_links =
                          value.collect do |dt|
                            if (i < max_data_type_to_show)
                              label = dt.send(config.object_label_method)
                              link = v.link_to(label, v.show_path(model_name: ::Setup::DataType.to_s.underscore.gsub('/', '~'), id: dt.id))
                            end
                            i+=1
                            link
                          end.to_sentence(options = { last_word_connector: ', ' })

                        message = "<span>Showing data types for #{key} method at #{name}</em></span>"
                        filter_token = Cenit::Token.create(data: { criteria: value.selector, message: message }, token_span: 1.hours)
                        index_action = v.action(:index, am)
                        link_more = v.link_to("more", v.url_for(action: index_action.action_name, model_name: ::Setup::DataType.to_s.underscore.gsub('/', '~'),filter_token: filter_token.token), class: 'pjax')
                        links = "#{first_links} and #{count - max_data_type_to_show} #{link_more}"
                      else
                        links = value.collect do |dt|
                          label = dt.send(config.object_label_method)
                          v.link_to(label, v.show_path(model_name: ::Setup::DataType.to_s.underscore.gsub('/', '~'), id: dt.id))
                        end.to_sentence
                      end
                      html+= "<li>#{key}: <span>#{links}</span></li>"
                    end
                  end
                end
                html += '</ul>'
                html.html_safe
              rescue Exception => ex
                "ERROR: #{ex.message}"
              end
            end
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

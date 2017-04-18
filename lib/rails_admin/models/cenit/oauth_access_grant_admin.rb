module RailsAdmin
  module Models
    module Cenit
      module OauthAccessGrantAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            label 'Access Grants'
            weight 340

            configure :scope, :cenit_oauth_scope
            show do
              field :scope do
                pretty_value do
                  cenit_oauth_scope = ::Cenit::OauthScope.new(value).access_by_ids
                  methods = Hash.new { |h, k| h[k] = [] }
                  cenit_oauth_scope.each_criteria do |method, criteria|
                    criteria['_id']['$in'].each { |id| methods[method] << id }
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
                    if value == true
                      html+= "<li>#{key}</li>"
                      next
                    end
                    if key == 'openid'
                      value = value.join(',')
                      html+= "<li>#{value}</li>"
                      next
                    end
                    if key == 'super_methods_set'
                      value = value.join(',')
                      html+= "<li>#{value}</li>"
                      next
                    end
                    if value.is_a?(Array)
                      config = RailsAdmin.config(::Setup::DataType)
                      links = value.collect do |data_type|
                        next unless (dt = Setup::DataType.where(id: data_type).first)
                        label = dt.send(config.object_label_method)
                        (v = bindings[:view]).link_to(label, v.show_path(model_name: ::Setup::DataType.to_s.underscore.gsub('/', '~'), id: data_type))
                      end.to_sentence.html_safe
                      html+= "<li>#{key}: <span>#{links}</span></li>"
                    end
                  end
                  html += '<ul>'
                  html.html_safe
                end
              end
            end


            fields :created_at, :application_id, :scope
          end
        end

      end
    end
  end
end

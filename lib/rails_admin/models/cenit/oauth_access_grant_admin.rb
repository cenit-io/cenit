module RailsAdmin
  module Models
    module Cenit
      module OauthAccessGrantAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            navigation_icon 'fa fa-key'
            label 'Access Grants'
            weight 340

            configure :application_id do
              read_only true
              help ''
            end

            configure :scope, :cenit_oauth_scope do
              help ''
            end

            show do
              field :created_at
              field :application_id
              field :scope
              field :tokens do
                pretty_value do
                  now = Time.now
                  table = <<-HTML
            <table class="table table-condensed table-striped">
              <thead>
                <tr>
                  <th>Token</th>
                  <th>Span</th>
                  <th class="last shrink"></th>
                <tr>
              </thead>
              <tbody>
          #{value.collect do |oauth_token|
                    expires_in =  oauth_token.expires_at
                    if expires_in
                      expires_in = expires_in - now
                      if expires_in < 0
                        expires_in = 'expired'
                      else
                        expires_in = expires_in.to_time_span
                      end
                    else
                      expires_in = 'never'
                    end
                    "<tr class=\"script_row\"><td>#{oauth_token.token}</td><td>#{expires_in}</td>
                    <td>
                       <a href=\"/oauth_access_token/#{oauth_token.id}/delete\">
                          <i class=\"fa fa-times alert-danger\"></i>
                        </a>
                    </td>"
                  end.join}
              </tbody>
            </table>
                  HTML
                  table.html_safe
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

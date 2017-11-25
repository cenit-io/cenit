module RailsAdmin
  module DashboardHelper
    def percent(count = 0, max)
      count > 0 ? (max <= 1 ? count : ((Math.log(count+1) * 100.0) / Math.log(max+1)).to_i) : -1
    end

    def animate_length(percent)
      [1.0, percent].max.to_i * 20
    end

    def integration_sample(index = 3)
      # TODO: Use some configuration attribute to select the sample apis
      sample = public_apis.sample(index)
      links = []
      sample.each do |a|
        url_show = rails_admin.show_path(model_name: a.model_name.to_s.underscore.gsub('/', '~'), id: a.name)
        links << link_to(a.name, url_show)
      end
      links.to_sentence.html_safe
    end


    def animate_width_to(percent)
      "#{[2.0, percent].max.to_i}%"
    end

    def recent_users
      User.order(created_at: :desc).limit(6).sample(2)
    end

    def tenant_users
      [current_user]
    end

    def monitor_totals
      totals = Hash.new { |r, h| r[h] = Hash.new { |k, v| k[v] = 0 } }
      if current_user
        totals[:tasks] = {
          total: Setup::Task.any_in(status: Setup::Task::RUNNING_STATUS).count,
          failed: Setup::Task.where(status: :failed).count,
          broken: Setup::Task.where(status: :broken).count,
          unscheduled: Setup::Task.where(status: :unscheduled).count,
          pending: Setup::Task.where(status: :pending).count,
          retrying: Setup::Task.where(status: :retrying).count,
          paused: Setup::Task.where(status: :paused).count,
          running: Setup::Task.where(status: :running).count,
          completed: Setup::Task.where(status: :completed).count
        }
        totals[:auths] = {
          total: Setup::Authorization.all.count,
          unauthorized: Setup::Authorization.where(authorized: false).count
        }
        totals[:notif] = {
          total: Setup::SystemNotification.dashboard_related[:total],
          error: Setup::SystemNotification.dashboard_related[Setup::SystemNotification.type_color(:error)],
          info: Setup::SystemNotification.dashboard_related[Setup::SystemNotification.type_color(:info)],
          notice: Setup::SystemNotification.dashboard_related[Setup::SystemNotification.type_color(:notice)],
          warning: Setup::SystemNotification.dashboard_related[Setup::SystemNotification.type_color(:warning)]
        }
      end
      totals
    end

    def categories_list categories
      list = ''
      categories.each do |cat|
        message = "<span><em>Setup::CrossSharedCollection</em> with category <em>#{cat.title}</em></span>"
        filter_token = Cenit::Token.where('data.category_id' => cat.id).first || Cenit::Token.create(data: { criteria: values.selector, message: message, category_id: cat.id })
        sub_link_url = index_path(model_name: Setup::CrossSharedCollection.to_s.underscore.gsub('/', '~'), filter_token: filter_token.token)
        list +=
          content_tag :li do
            link_to sub_link_url, title: cat.description do
              "#{cat.title}"
            end
          end
      end
      list.html_safe
    end

    def status_color v
      if v < 20
        'success'
      else
        if v < 100
          'warning'
        else
          'danger'
        end
      end
    end
  end
end




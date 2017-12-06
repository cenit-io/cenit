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

    def tenant_monitor_data
      acc_am = RailsAdmin::Config.model(Cenit::MultiTenancy.tenant_model).abstract_model
      { name: name = current_user.account.name.split('@')[0],
        icon: 'fa fa-home',
        url: inspect_path(model_name: acc_am.to_param, id: current_user.account.id),
        menu: tenant_monitor_menu,
        value: value = current_user.all_accounts.count,
        actions: [{ label: 'tenants', class: name, value: value, description: 'tenants' }]
      }
    end

    def task_monitor_data tasks
      if (value = tasks[:failed]) > 0
        value = number_to_human(value)
        label = 'failed'
      elsif (value = tasks[:broken]) > 0
        value = number_to_human(value)
        label = 'broken'
      elsif (value = tasks[:unscheduled]) > 0
        value = number_to_human(value)
        label = 'unscheduled'
      elsif (value = tasks[:pending]) > 0
        value = number_to_human(value)
        label = 'pending'
      elsif (value = tasks[:retrying]) > 0
        value = number_to_human(value)
        label = 'retrying'
      elsif (value = tasks[:paused]) > 0
        value = number_to_human(value)
        label = 'paused'
      elsif (value = tasks[:running]) > 0
        value = number_to_human(value)
        label = 'running'
      else
        value = number_to_human(tasks[:completed])
        label = 'completed'
      end
      name = t('admin.actions.dashboard.monitors.tasks')
      icon= 'fa-tasks'
      url= '/task'
      actions = [{ label: 'failed', class: 'failed', value: tasks[:failed], description: 'failed' },
                 { label: 'broken', class: 'broken', value: tasks[:broken], description: 'broken' },
                 { label: 'unscheduled', class: 'unscheduled', value: tasks[:unscheduled], description: 'unscheduled' },
                 { label: 'pending', class: 'pending', value: tasks[:pending], description: 'pending' },
                 { label: 'retrying', class: 'retrying', value: tasks[:retrying], description: 'retrying' },
                 { label: 'paused', class: 'paused', value: tasks[:paused], description: 'paused' },
                 { label: 'running', class: 'running', value: tasks[:running], description: 'running' },
                 { label: 'completed', class: 'completed', value: tasks[:completed], description: 'completed' }]
      { name: name,
        icon: icon,
        url: url,
        label: label,
        value: value,
        label_name: label,
        actions: actions
      }
    end

    def auth_monitor_data auth
      if (value = auth[:unauthorized]) == 0
        value = auth[:total]
        label = 'total'
      else
        value = number_to_human(value)
        label = 'unauthorized'
      end
      name = t('admin.actions.dashboard.monitors.auths')
      icon= 'fa-check'
      url= '/authorization'
      actions = [{ label: 'total', class: 'total', value: auth[:total], description: 'total' },
                 { label: 'unauthorized', class: 'unauthorized', value: auth[:unauthorized], description: 'unauthorized' }]
      { name: name,
        icon: icon,
        url: url,
        label: label,
        value: value,
        label_name: label,
        actions: actions
      }
    end

    def notif_monitor_data notif
      abstract_model = linking(Setup::SystemNotification)
      if (value = notif[:error]) > 0
        value = number_to_human(value)
        label = 'errors'
      elsif (value = notif[:warning]) > 0
        value = number_to_human(value)
        label = 'warnings'
      elsif (value = notif[:notice]) > 0
        value = number_to_human(value)
        label = 'notice'
      elsif (value = notif[:info]) > 0
        value = number_to_human(value)
        label = 'info'
      else
        value = notif[:total]
        label = 'total'
      end
      name = t('admin.actions.dashboard.monitors.notif')
      icon= 'fa-bell'
      url = '/system_notification'

      actions = [{ label: 'total', class: 'total', value: notif[:total], description: 'total' },
                 { label: 'errors', class: 'errors', value: notif[:error], description: 'errors' },
                 { label: 'warnings', class: 'warnings', value: notif[:warning], description: 'warnings'},
                 { label: 'notice', class: 'notice', value: notif[:notice], description: 'notices' },
                 { label: 'info', class: 'info', value: notif[:info], description: 'info'}]
      { url: url,
        label_name: label,
        value: value,
        name: name,
        icon: icon,
        actions: actions
      }
    end

    def model_monitor_data m
      name = m[:label]
      icon= m[:icon]
      url = m[:url]
      menu = m[:menu]
      model = m[:data][:model]
      origins = m[:data][:origins]
      indicator = m[:indicator]
      { url: url,
        label_name: name,
        value: 'loading',
        name: name,
        icon: icon,
        menu: menu,
        model: model,
        origins: origins,
        indicator: indicator }
    end

    def tenant_monitor_menu
      acc_am = RailsAdmin::Config.model(Cenit::MultiTenancy.tenant_model).abstract_model
      menu = []
      menu <<
        if (new_action = action(:new, acc_am))
          url = url_for(action: new_action.action_name, model_name: acc_am.to_param)
          name = 'Add new'
          %(<li title="Add new" rel="" class="icon index_collection_link ">
            <a class="pjax" href="#{url}">
              <i class="fa fa-plus"></i>
              <span>#{name}</span>
            </a>
          </li>)
        end
      current_user.all_accounts.each do |a|
        if a != current_user.account
          name = format_name(a.name)
          url = inspect_path(model_name: acc_am.to_param, id: a.id)
          menu << %(<li title="Inspect #{name}" rel="" class="icon index_collection_link ">
              <a class="pjax" href="#{url}">
                <i class="fa fa-home"></i>
                <span>#{name}</span>
              </a>
            </li>)
        end
      end
      menu.join.html_safe
    end

  end
end




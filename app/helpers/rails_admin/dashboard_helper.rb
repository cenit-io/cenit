module RailsAdmin
  module DashboardHelper
    def percent(count = 0, max)
      count > 0 ? (max <= 1 ? count : ((Math.log(count+1) * 100.0) / Math.log(max+1)).to_i) : -1
    end
    
    def animate_length(percent)
      [1.0, percent].max.to_i * 20
    end
    
    def animate_width_to(percent)
      "#{[2.0, percent].max.to_i}%"
    end

    def recent_users
      User.order(created_at: :desc).limit(10).sample(5)
    end

    def monitor_totals
      totals = Hash.new { |r, h| r[h] = Hash.new { |k, v| k[v] = 0}}
      if current_user
        totals[:tasks] = {
            total: Setup::Task.any_in(status: Setup::Task::RUNNING_STATUS).count,
            failed: Setup::Task.where(status: :failed).count,
            broken: Setup::Task.where(status: :broken).count,
            unscheduled: Setup::Task.where(status: :unscheduled).count,
            pending: Setup::Task.where(status: :pending).count
        }
        totals[:auths] = {
            total: Setup::Authorization.all.count,
            unauthorized: Setup::Authorization.where(authorized: false).count
        }
        totals[:notif] = {
            total: Setup::Notification.dashboard_related[:total],
            error: Setup::Notification.dashboard_related[Setup::Notification.type_color(:error)],
            warning: Setup::Notification.dashboard_related[Setup::Notification.type_color(:warning)]
        }
      end
      totals
    end

  end
end
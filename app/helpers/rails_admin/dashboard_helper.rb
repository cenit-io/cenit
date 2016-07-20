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

    def recent_users()
      User.order(created_at: :desc).limit(10).sample(5)
    end

  end
end
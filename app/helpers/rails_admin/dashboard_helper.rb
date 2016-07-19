require 'net/http'

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

    def gravatar(user)
      gravatar_check = "//gravatar.com/avatar/#{Digest::MD5.hexdigest(user.email.downcase)}.png?d=404"
      uri = URI.parse(gravatar_check)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new("/avatar/#{Digest::MD5.hexdigest(user.email.downcase)}.png?d=404")
      response = http.request(request)
      response.code.to_i != 404 # from d=404 parameter
    end
  end
end
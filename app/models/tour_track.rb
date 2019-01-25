class TourTrack
  include Mongoid::Document
  include Mongoid::Timestamps
  include ::RailsAdmin::Models::TourTrackAdmin

  field :ip, type: String
  field :user_email, type: String

  def to_s
    "Tour Track #{ip} - #{user_email}"
  end

  class << self

    def show_tour? (ip, user)
      anonymous = user.nil?
      show_tour =  (anonymous ? where(ip: ip, :user_email.exists => false) : where(user_email: user.email)).blank?
      if show_tour
        attributes = anonymous ? { ip: ip } : { user_email: user.email, ip: ip }
        new(attributes).save
      end
      show_tour
    end
  end
end

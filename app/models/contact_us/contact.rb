module ContactUs
  class Contact
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, type: String
    field :email, type: String
    field :message, type: String
    field :subject, type: String

    validates :email,
      :format => { :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i },
      :presence => true
    validates :message, :presence => true
    validates :name, :presence => { :if => Proc.new { ContactUs.require_name } }
    validates :subject, :presence => { :if => Proc.new { ContactUs.require_subject } }

    def save
      super
      if self.valid?
        ContactUs::ContactMailer.contact_email(self).deliver
        return true
      end
      return false
    end
  end
end

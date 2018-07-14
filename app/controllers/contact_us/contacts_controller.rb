module ContactUs
  class ContactsController < ApplicationController

    def create
      @contact = ContactUs::Contact.new(permitted_attributes)
      begin
        verified = ENV['ENABLE_RERECAPTCHA'].to_b.blank? || ENV['RECAPTCHA_SITE_KEY'].blank? || verify_recaptcha(model: @contact)
        if verified && @contact.save
          redirect_to '/thanks.html'
        else
          flash[:error] = t('admin.contact_us.notices.error')
          redirect_to root_path
        end
      rescue Exception => ex
        Setup::SystemNotification.create_from(ex)
        flash[:error] = "#{t('admin.contact_us.notices.error')}.An Exception happened: #{ex.message}.See your Notifications for more details"
        redirect_to root_path
      end
    end

    def new
      @contact = ContactUs::Contact.new
    end

    private

    def permitted_attributes
      params.require(:contact_us_contact).permit(:name, :email, :message, :subject)
    end
  end
end

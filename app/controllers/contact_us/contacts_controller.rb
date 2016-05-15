class ContactUs::ContactsController < ApplicationController

  def create
    @contact = ContactUs::Contact.new(permited_attributes)
    if @contact.save
      redirect_to('/', :notice => t('contact_us.notices.success'))
    else
      flash[:error] = t('contact_us.notices.error')
      redirect_to root_path
    end
  end

  def new
    @contact = ContactUs::Contact.new
  end
  
  private
  
  def permited_attributes
    params.require(:contact_us_contact).permit(:name, :email, :message)
  end  

end

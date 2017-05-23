module RailsAdmin
  MainHelper.class_eval do

    alias_method :ra_rails_admin_form_for, :rails_admin_form_for

    def rails_admin_form_for(*args, &block)
      ra_rails_admin_form_for(*args, &block)
    rescue Exception => ex
      Setup::SystemReport.create_from(ex)
      render partial: 'form_notice', locals: { message: ex }
    end
  end
end

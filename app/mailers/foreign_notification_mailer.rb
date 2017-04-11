class ForeignNotificationMailer < ActionMailer::Base
  def send_email(to, subject, body)
    # TODO: Use custom email provider.
    from = ContactUs.config.mailer_from
    mail from: from, reply_to: from, to: to, subject: subject, body: body, content_type: "text/html"
  end
end

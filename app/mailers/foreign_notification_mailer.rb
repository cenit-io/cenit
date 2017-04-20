class ForeignNotificationMailer < ActionMailer::Base
  def send_email(to, subject, body, delivery_options = {})
    # TODO: Use custom email provider.
    from = ContactUs.config.mailer_from
    mail(
      from: from,
      reply_to: from,
      to: to,
      subject: subject,
      body: body,
      content_type: "text/html",
      delivery_method_options: delivery_options
    )
  end
end

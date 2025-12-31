# frozen_string_literal: truell

# Custom event handler for sending welcome emails
#
# This handler demonstrates how to create custom domain-specific handlers
# that respond to specific events and trigger side effects.
class UserWelcomeHandler < SmartDomain::Event::Handler
  def can_handle?(event_type)
    event_type == "user.created"
  end

  def handle(event)
    Rails.logger.info "[UserWelcomeHandler] Sending welcome email to #{event.email}"

    # In a real application, this would call a mailer:
    # UserMailer.welcome_email(event.user_id).deliver_later

    # For this example, we'll just log
    Rails.logger.info "[UserWelcomeHandler] Welcome email sent to #{event.email}"
  end
end

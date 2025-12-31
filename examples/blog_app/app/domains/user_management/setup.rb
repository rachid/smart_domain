# frozen_string_literal: true

module UserManagement
  # Setup event handlers for user domain
  #
  # This file is automatically loaded by SmartDomain::Railtie
  # when the Rails application starts.
  def self.setup!
    # Register standard handlers (audit and metrics)
    # This one line replaces ~50 lines of boilerplate!
    SmartDomain::Event::Registration.register_standard_handlers(
      domain: 'user',
      events: %w[created updated deleted],
      include_audit: true,
      include_metrics: true
    )

    # Register custom handlers
    welcome_handler = UserWelcomeHandler.new
    SmartDomain::Event.bus.subscribe('user.created', welcome_handler)

    Rails.logger.info "[UserManagement] Domain setup complete"
    Rails.logger.info "[UserManagement] Registered handlers: audit, metrics, welcome email"
  end
end

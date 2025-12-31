# frozen_string_literal: true

module PostManagement
  # Setup event handlers for post domain
  #
  # This file is automatically loaded by SmartDomain::Railtie
  # when the Rails application starts.
  def self.setup!
    # Register standard handlers (audit and metrics)
    # This one line replaces ~50 lines of boilerplate!
    SmartDomain::Event::Registration.register_standard_handlers(
      domain: 'post',
      events: %w[created updated deleted],
      include_audit: true,
      include_metrics: true
    )

    # Register custom handlers
    notification_handler = PostNotificationHandler.new
    SmartDomain::Event.bus.subscribe('post.updated', notification_handler)

    Rails.logger.info "[PostManagement] Domain setup complete"
    Rails.logger.info "[PostManagement] Registered handlers: audit, metrics, notifications"
  end
end

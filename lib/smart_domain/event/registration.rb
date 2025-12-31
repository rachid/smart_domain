# frozen_string_literal: true

require_relative '../handlers/audit_handler'
require_relative '../handlers/metrics_handler'

module SmartDomain
  module Event
    # Event registration helpers for standardized handler setup.
    #
    # This module provides convenience methods to register common event handlers
    # (audit, metrics) for domains, reducing boilerplate by approximately 70%.
    #
    # Instead of manually subscribing audit and metrics handlers to each event:
    #
    #   audit = AuditHandler.new('user')
    #   metrics = MetricsHandler.new('user')
    #   bus.subscribe('user.created', audit)
    #   bus.subscribe('user.created', metrics)
    #   bus.subscribe('user.updated', audit)
    #   bus.subscribe('user.updated', metrics)
    #   # ... repeat for all events ...
    #
    # Use this one-liner:
    #
    #   SmartDomain::Event::Registration.register_standard_handlers(
    #     domain: 'user',
    #     events: ['created', 'updated', 'deleted'],
    #     include_audit: true,
    #     include_metrics: true
    #   )
    #
    # Custom handlers (email, security, etc.) should still be registered explicitly.
    module Registration
      # Register standard audit and metrics handlers for a domain's events.
      #
      # This helper reduces boilerplate by automatically registering generic
      # audit and metrics handlers for all events in a domain. Custom handlers
      # (email, security, etc.) should still be registered explicitly.
      #
      # @param domain [String] Domain name (e.g., 'user', 'order', 'product')
      # @param events [Array<String>] List of event actions (e.g., ['created', 'updated', 'deleted'])
      # @param include_audit [Boolean] Whether to register audit handler (default: true)
      # @param include_metrics [Boolean] Whether to register metrics handler (default: true)
      # @return [Hash] Dictionary mapping handler type to list of registered event types
      #
      # @example Domain setup file
      #   # app/domains/user_management/setup.rb
      #   module UserManagement
      #     def self.setup!
      #       # Register standard handlers
      #       SmartDomain::Event::Registration.register_standard_handlers(
      #         domain: 'user',
      #         events: %w[created updated deleted activated suspended],
      #         include_audit: true,
      #         include_metrics: true
      #       )
      #
      #       # Custom handlers still explicit
      #       email_handler = UserEmailHandler.new
      #       SmartDomain::Event.bus.subscribe('user.created', email_handler)
      #       SmartDomain::Event.bus.subscribe('user.activated', email_handler)
      #     end
      #   end
      def self.register_standard_handlers(domain:, events:, include_audit: true, include_metrics: true)
        registered = { audit: [], metrics: [] }
        logger = SmartDomain.configuration.logger

        if include_audit
          audit_handler = SmartDomain::Handlers::AuditHandler.new(domain)
          events.each do |action|
            event_type = "#{domain}.#{action}"
            SmartDomain::Event.bus.subscribe(event_type, audit_handler)
            registered[:audit] << event_type
          end
        end

        if include_metrics
          metrics_handler = SmartDomain::Handlers::MetricsHandler.new(domain)
          events.each do |action|
            event_type = "#{domain}.#{action}"
            SmartDomain::Event.bus.subscribe(event_type, metrics_handler)
            registered[:metrics] << event_type
          end
        end

        # Log what was registered
        if include_audit || include_metrics
          handlers_registered = []
          handlers_registered << 'audit' if include_audit
          handlers_registered << 'metrics' if include_metrics

          logger.info "[SmartDomain::Registration] Standard handlers registered for #{domain} domain: " \
                      "#{handlers_registered.join(', ')} (#{events.size} events)"
          logger.debug "[SmartDomain::Registration] Event types: #{events.map { |a| "#{domain}.#{a}" }.join(', ')}"
        end

        registered
      end

      # Register custom event handlers for a domain.
      #
      # This is a convenience method for registering multiple custom handlers
      # to multiple events. Use this when you have custom handlers that need to
      # listen to multiple events.
      #
      # @param domain [String] Domain name (for logging purposes)
      # @param handlers [Hash] Hash mapping handler instances to list of event actions
      #
      # @example
      #   # app/domains/user_management/setup.rb
      #   email_handler = UserEmailHandler.new
      #   security_handler = UserSecurityHandler.new
      #
      #   SmartDomain::Event::Registration.register_domain_handlers(
      #     domain: 'user',
      #     handlers: {
      #       email_handler => ['created', 'activated', 'suspended'],
      #       security_handler => ['suspended', 'deleted']
      #     }
      #   )
      def self.register_domain_handlers(domain:, handlers:)
        logger = SmartDomain.configuration.logger

        handlers.each do |handler, event_actions|
          event_actions.each do |action|
            event_type = "#{domain}.#{action}"
            SmartDomain::Event.bus.subscribe(event_type, handler)
          end
        end

        logger.info "[SmartDomain::Registration] Custom handlers registered for #{domain} domain " \
                    "(#{handlers.size} handler(s))"
      end
    end
  end
end

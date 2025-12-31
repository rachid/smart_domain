# frozen_string_literal: true

module SmartDomain
  module Handlers
    # Generic metrics handler for domain events.
    #
    # This handler collects metrics from domain events for monitoring
    # and analytics. It can integrate with metrics systems like StatsD,
    # Datadog, Prometheus, or CloudWatch.
    #
    # By default, it logs metrics to the Rails logger. You can override
    # #emit_metric to send to your metrics backend.
    #
    # @example
    #   user_metrics = SmartDomain::Handlers::MetricsHandler.new('user')
    #   SmartDomain::Event.bus.subscribe('user.created', user_metrics)
    #
    # @example Custom metrics backend
    #   class CustomMetricsHandler < SmartDomain::Handlers::MetricsHandler
    #     def emit_metric(metric_name, tags)
    #       StatsD.increment(metric_name, tags: tags)
    #     end
    #   end
    class MetricsHandler < Event::Handler
      attr_reader :domain, :logger

      # Initialize metrics handler for a specific domain
      # @param domain [String] Domain name (e.g., 'user', 'order', 'product')
      def initialize(domain)
        super()
        @domain = domain
        @logger = SmartDomain.configuration.logger
      end

      # Check if this handler can handle an event type
      # @param event_type [String] Event type to check
      # @return [Boolean] True if event belongs to this domain
      def can_handle?(event_type)
        return true if @domain == '*'

        event_type.start_with?("#{@domain}.")
      end

      # Handle metrics collection for an event
      # @param event [SmartDomain::Event::Base] Event to collect metrics from
      def handle(event)
        metric_name = build_metric_name(event)
        tags = build_metric_tags(event)

        # Emit counter metric
        emit_metric(metric_name, tags)

        # Emit timing metric if duration is present
        if event.respond_to?(:duration) && event.duration
          timing_name = "#{metric_name}.duration"
          emit_metric(timing_name, tags.merge(duration_ms: event.duration))
        end
      rescue StandardError => e
        # Never fail on metrics handler errors
        @logger.warn "[SmartDomain::MetricsHandler] Metrics collection failed: #{e.message}"
      end

      private

      # Build metric name from event
      # @param event [SmartDomain::Event::Base] Event
      # @return [String] Metric name (e.g., 'domain_events.user.created')
      def build_metric_name(event)
        "domain_events.#{event.event_type}"
      end

      # Build metric tags from event
      # @param event [SmartDomain::Event::Base] Event
      # @return [Hash] Metric tags
      def build_metric_tags(event)
        {
          aggregate_type: event.aggregate_type,
          organization_id: event.organization_id,
          domain: @domain
        }
      end

      # Emit metric to backend
      #
      # Override this method to integrate with your metrics backend.
      # Default implementation logs to Rails logger.
      #
      # @param metric_name [String] Metric name
      # @param tags [Hash] Metric tags
      def emit_metric(metric_name, tags)
        @logger.info("[METRIC] #{metric_name} - #{tags.to_json}")

        # Example integrations (commented out):
        #
        # StatsD:
        # StatsD.increment(metric_name, tags: tags)
        #
        # Datadog:
        # Datadog::Statsd.new.increment(metric_name, tags: tags.map { |k, v| "#{k}:#{v}" })
        #
        # Prometheus:
        # counter = Prometheus::Client.registry.counter(
        #   metric_name.tr('.', '_').to_sym,
        #   docstring: 'Domain event counter',
        #   labels: tags.keys
        # )
        # counter.increment(labels: tags)
      end
    end
  end
end

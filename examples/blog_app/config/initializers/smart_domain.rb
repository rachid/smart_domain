# frozen_string_literal: true

# SmartDomain configuration
SmartDomain.configure do |config|
  # Event bus adapter (:memory, :redis, :active_job)
  # :memory is synchronous and suitable for development/testing
  # :redis and :active_job are asynchronous and suitable for production
  config.event_bus_adapter = :memory

  # Enable automatic writes to audit_events table
  # Set to true if you have an AuditEvent model for compliance
  config.audit_table_enabled = false

  # Enable multi-tenancy support
  # Set to true if your application is multi-tenant
  config.multi_tenancy_enabled = true

  # Key used for tenant identification (e.g., :organization_id, :account_id)
  config.tenant_key = :organization_id

  # Use ActiveJob for asynchronous event handling
  # Requires config.event_bus_adapter to support async (not :memory)
  config.async_handlers = false

  # Logger instance
  config.logger = Rails.logger
end

# Example: Register standard handlers for a domain
# Uncomment and modify for your domains:
#
# SmartDomain::Event::Registration.register_standard_handlers(
#   domain: 'user',
#   events: %w[created updated deleted],
#   include_audit: true,
#   include_metrics: true
# )

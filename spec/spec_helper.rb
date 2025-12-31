# frozen_string_literal: true

require 'bundler/setup'
require 'smart_domain'
require 'active_record'
require 'logger'

# Configure ActiveRecord for testing
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Create audit_events table for testing
ActiveRecord::Schema.define do
  create_table :audit_events, force: true do |t|
    t.string :event_id, null: false
    t.string :event_type, null: false
    t.string :aggregate_id
    t.string :aggregate_type
    t.string :organization_id
    t.string :category
    t.string :risk_level
    t.json :event_data
    t.datetime :occurred_at
    t.timestamps
  end

  add_index :audit_events, :event_id, unique: true
  add_index :audit_events, :event_type
  add_index :audit_events, :organization_id
end

# AuditEvent model for testing
class AuditEvent < ActiveRecord::Base
end

# Configure SmartDomain
SmartDomain.configure do |config|
  config.event_bus_adapter = :memory
  config.audit_table_enabled = true
  config.logger = Logger.new(nil) # Silent logger for tests
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset event bus before each test
  config.before(:each) do
    # Clear all handlers
    SmartDomain::Event.bus.adapter.clear!

    # Clear tenant context
    SmartDomain::Integration::TenantContext.clear! if defined?(SmartDomain::Integration::TenantContext)

    # Clear audit events
    AuditEvent.delete_all if defined?(AuditEvent)
  end

  # Clean up after each test
  config.after(:each) do
    SmartDomain::Event.bus.adapter.clear!
  end
end

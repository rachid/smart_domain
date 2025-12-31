# frozen_string_literal: true

require 'active_model'
require 'active_support'
require 'active_support/core_ext'
require 'active_record'
require 'logger'

require_relative 'smart_domain/version'
require_relative 'smart_domain/configuration'

# Event system
require_relative 'smart_domain/event/base'
require_relative 'smart_domain/event/mixins'
require_relative 'smart_domain/event/handler'
require_relative 'smart_domain/event/adapters/memory'

# Handlers
require_relative 'smart_domain/handlers/audit_handler'
require_relative 'smart_domain/handlers/metrics_handler'

# Event registration
require_relative 'smart_domain/event/registration'

# Domain patterns
require_relative 'smart_domain/domain/exceptions'
require_relative 'smart_domain/domain/policy'
require_relative 'smart_domain/domain/service'

# Rails integration
require_relative 'smart_domain/integration/active_record'
require_relative 'smart_domain/integration/multi_tenancy'

# Railtie (loads automatically if Rails is present)
require_relative 'smart_domain/railtie' if defined?(Rails::Railtie)

# SmartDomain - Domain-Driven Design and Event-Driven Architecture for Rails
#
# SmartDomain brings battle-tested DDD/EDA patterns from the Aeyes healthcare
# platform to Rails applications. It provides:
#
# - Domain events with event bus
# - Event mixins for 70% boilerplate reduction
# - Generic handlers for audit and metrics
# - Domain service pattern
# - Rails generators for rapid scaffolding
#
# @example Quick Start
#   # In config/initializers/smart_domain.rb
#   SmartDomain.configure do |config|
#     config.event_bus_adapter = :memory
#     config.audit_table_enabled = true
#   end
#
#   # Define a domain event
#   class UserCreatedEvent < SmartDomain::Event::Base
#     attribute :user_id, :string
#     attribute :email, :string
#   end
#
#   # Publish an event
#   event = UserCreatedEvent.new(
#     event_type: 'user.created',
#     aggregate_id: user.id,
#     aggregate_type: 'User',
#     organization_id: org.id,
#     user_id: user.id,
#     email: user.email
#   )
#   SmartDomain::Event.bus.publish(event)
#
# @see https://github.com/rachidalmaach/smart_domain
module SmartDomain
  class Error < StandardError; end

  # Your code goes here...
end

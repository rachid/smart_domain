# frozen_string_literal: true

require 'logger'

module SmartDomain
  # Configuration for SmartDomain gem.
  #
  # Configure the gem in an initializer:
  #
  # @example config/initializers/smart_domain.rb
  #   SmartDomain.configure do |config|
  #     config.event_bus_adapter = :memory
  #     config.audit_table_enabled = true
  #     config.multi_tenancy_enabled = true
  #     config.tenant_key = :organization_id
  #     config.async_handlers = false
  #     config.logger = Rails.logger
  #   end
  class Configuration
    # Event bus adapter to use (:memory, :redis, :active_job)
    # @return [Symbol, Object] Adapter symbol or adapter instance
    attr_accessor :event_bus_adapter

    # Enable automatic writes to audit_events table
    # @return [Boolean]
    attr_accessor :audit_table_enabled

    # Enable multi-tenancy support
    # @return [Boolean]
    attr_accessor :multi_tenancy_enabled

    # Key used for tenant identification (e.g., :organization_id, :account_id)
    # @return [Symbol]
    attr_accessor :tenant_key

    # Use ActiveJob for asynchronous event handling
    # @return [Boolean]
    attr_accessor :async_handlers

    # Logger instance for SmartDomain
    # @return [Logger]
    attr_accessor :logger

    # Initialize configuration with defaults
    def initialize
      @event_bus_adapter = nil # Will use Memory adapter
      @audit_table_enabled = false
      @multi_tenancy_enabled = false
      @tenant_key = :organization_id
      @async_handlers = false
      @logger = Logger.new($stdout)
    end

    # Check if audit table writes are enabled
    # @return [Boolean]
    def audit_table_enabled?
      @audit_table_enabled == true
    end

    # Check if multi-tenancy is enabled
    # @return [Boolean]
    def multi_tenancy_enabled?
      @multi_tenancy_enabled == true
    end

    # Check if async handlers are enabled
    # @return [Boolean]
    def async_handlers?
      @async_handlers == true
    end
  end

  # Get or create the configuration instance
  # @return [SmartDomain::Configuration]
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure SmartDomain
  #
  # @example
  #   SmartDomain.configure do |config|
  #     config.event_bus_adapter = :memory
  #     config.audit_table_enabled = true
  #   end
  #
  # @yield [Configuration] The configuration object
  def self.configure
    yield(configuration)
  end

  # Reset configuration to defaults (useful for testing)
  # @api private
  def self.reset_configuration!
    @configuration = Configuration.new
  end
end

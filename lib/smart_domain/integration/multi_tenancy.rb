# frozen_string_literal: true

module SmartDomain
  module Integration
    # Multi-tenancy support for SmartDomain.
    #
    # Provides thread-safe tenant context management for multi-tenant applications.
    # The current tenant is stored in thread-local storage to ensure isolation
    # between concurrent requests.
    #
    # @example Set tenant in a controller
    #   class ApplicationController < ActionController::Base
    #     around_action :set_current_tenant
    #
    #     private
    #
    #     def set_current_tenant
    #       SmartDomain::Integration::TenantContext.with_tenant(current_organization.id) do
    #         yield
    #       end
    #     end
    #   end
    #
    # @example Use in service
    #   class UserService < SmartDomain::Domain::Service
    #     def create_user(attributes)
    #       tenant_id = SmartDomain::Integration::TenantContext.current
    #       # ... use tenant_id ...
    #     end
    #   end
    module TenantContext
      # Get the current tenant ID from thread-local storage
      #
      # @return [String, Integer, nil] Current tenant ID
      def self.current
        Thread.current[:smart_domain_tenant_id]
      end

      # Set the current tenant ID
      #
      # @param tenant_id [String, Integer, nil] Tenant ID to set
      def self.current=(tenant_id)
        Thread.current[:smart_domain_tenant_id] = tenant_id
      end

      # Execute a block within a tenant context
      #
      # Ensures the previous tenant is restored after the block executes,
      # even if an exception is raised.
      #
      # @param tenant_id [String, Integer] Tenant ID
      # @yield Block to execute within tenant context
      # @return [Object] Result of the block
      #
      # @example
      #   TenantContext.with_tenant('org-123') do
      #     user = User.create!(email: 'test@example.com')
      #     # user.organization_id will be 'org-123'
      #   end
      def self.with_tenant(tenant_id)
        previous_tenant = current
        self.current = tenant_id
        yield
      ensure
        self.current = previous_tenant
      end

      # Clear the current tenant
      def self.clear!
        Thread.current[:smart_domain_tenant_id] = nil
      end

      # Check if a tenant is set
      #
      # @return [Boolean]
      def self.tenant_set?
        current.present?
      end
    end

    # ActiveRecord concern for automatic tenant assignment
    #
    # @example Include in a model
    #   class User < ApplicationRecord
    #     include SmartDomain::Integration::TenantScoped
    #
    #     # organization_id will be automatically set from TenantContext.current
    #   end
    module TenantScoped
      extend ActiveSupport::Concern

      included do
        # Set tenant on create if not already set
        before_validation :set_tenant_from_context, on: :create

        # Validate tenant is present
        validates SmartDomain.configuration.tenant_key, presence: true

        # Default scope to current tenant (optional - can be disabled)
        # default_scope -> { where(organization_id: TenantContext.current) if TenantContext.tenant_set? }
      end

      private

      # Set tenant from thread-local context
      def set_tenant_from_context
        tenant_key = SmartDomain.configuration.tenant_key
        return if public_send(tenant_key).present?
        return unless TenantContext.tenant_set?

        public_send("#{tenant_key}=", TenantContext.current)
      end
    end
  end
end

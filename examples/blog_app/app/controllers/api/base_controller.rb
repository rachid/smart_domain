# frozen_string_literal: true

module Api
  # Base API controller with common functionality
  class BaseController < ApplicationController
    # Skip CSRF for API requests
    skip_before_action :verify_authenticity_token

    # Simple authentication simulation
    # In a real app, this would use JWT, sessions, etc.
    before_action :set_current_organization
    before_action :set_current_user

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from SmartDomain::Domain::Exceptions::UnauthorizedError, with: :forbidden

    private

    def set_current_organization
      # In real app: decode from JWT, session, subdomain, etc.
      # For demo: use header or first organization
      org_id = request.headers['X-Organization-Id']
      @current_organization = if org_id
        Organization.find(org_id)
      else
        Organization.first || Organization.create!(name: "Demo Organization")
      end
    end

    def set_current_user
      # In real app: decode from JWT token
      # For demo: use header or create demo user
      user_id = request.headers['X-User-Id']
      @current_user = if user_id
        User.find(user_id)
      else
        # Create a demo admin user if none exists
        @current_organization.users.first || @current_organization.users.create!(
          email: "admin@example.com",
          name: "Demo Admin",
          role: "admin"
        )
      end
    end

    attr_reader :current_user, :current_organization

    def not_found(exception)
      render json: { error: exception.message }, status: :not_found
    end

    def unprocessable_entity(exception)
      render json: { error: exception.message, details: exception.record.errors }, status: :unprocessable_entity
    end

    def forbidden(exception)
      render json: { error: exception.message }, status: :forbidden
    end
  end
end

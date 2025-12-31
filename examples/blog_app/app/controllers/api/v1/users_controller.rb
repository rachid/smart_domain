# frozen_string_literal: true

module Api
  module V1
    # Users API Controller
    #
    # Demonstrates:
    # - Thin controller delegating to UserService (domain layer)
    # - Policy authorization using UserPolicy
    # - Multi-tenancy with current_organization
    # - Events automatically published via service layer
    class UsersController < Api::BaseController
      before_action :set_user, only: [:show, :update, :destroy]

      # GET /api/v1/users
      def index
        # Automatically scoped to current_organization via TenantScoped
        @users = SmartDomain::Integration::TenantContext.with_tenant(current_organization.id) do
          User.all
        end

        render json: @users
      end

      # GET /api/v1/users/:id
      def show
        authorize @user, :show?
        render json: @user
      end

      # POST /api/v1/users
      def create
        service = UserManagement::UserService.new(
          current_user: current_user,
          organization_id: current_organization.id
        )

        # Service handles:
        # 1. Business logic validation
        # 2. Creating the user
        # 3. Publishing UserCreatedEvent
        # 4. Triggering handlers (audit, metrics, welcome email)
        @user = service.create_user(user_params)

        render json: @user, status: :created
      end

      # PATCH/PUT /api/v1/users/:id
      def update
        authorize @user, :update?

        service = UserManagement::UserService.new(
          current_user: current_user,
          organization_id: current_organization.id
        )

        # Service publishes UserUpdatedEvent with change tracking
        @user = service.update_user(@user, user_params)

        render json: @user
      end

      # DELETE /api/v1/users/:id
      def destroy
        authorize @user, :destroy?

        service = UserManagement::UserService.new(
          current_user: current_user,
          organization_id: current_organization.id
        )

        # Service publishes UserDeletedEvent
        service.delete_user(@user)

        head :no_content
      end

      private

      def set_user
        @user = SmartDomain::Integration::TenantContext.with_tenant(current_organization.id) do
          User.find(params[:id])
        end
      end

      def user_params
        params.require(:user).permit(:email, :name, :role)
      end

      def authorize(user, action)
        policy = UserPolicy.new(current_user, user)
        unless policy.public_send(action)
          raise SmartDomain::Domain::Exceptions::UnauthorizedError, "Not authorized to #{action} this user"
        end
      end
    end
  end
end

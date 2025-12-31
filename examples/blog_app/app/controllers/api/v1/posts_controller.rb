# frozen_string_literal: true

module Api
  module V1
    # Posts API Controller
    #
    # Demonstrates:
    # - Thin controller delegating to PostService (domain layer)
    # - Policy authorization using PostPolicy
    # - Custom actions (publish/unpublish) triggering events
    # - Change tracking in update events
    class PostsController < Api::BaseController
      before_action :set_post, only: [:show, :update, :destroy, :publish, :unpublish]

      # GET /api/v1/posts
      def index
        @posts = SmartDomain::Integration::TenantContext.with_tenant(current_organization.id) do
          # Optional filter by published status
          scope = Post.includes(:user)
          scope = params[:published] == 'true' ? scope.published : scope if params[:published].present?
          scope.all
        end

        render json: @posts, include: :user
      end

      # GET /api/v1/posts/:id
      def show
        authorize @post, :show?
        render json: @post, include: :user
      end

      # POST /api/v1/posts
      def create
        service = PostManagement::PostService.new(
          current_user: current_user,
          organization_id: current_organization.id
        )

        # Service handles:
        # 1. Validation
        # 2. Creating the post
        # 3. Publishing PostCreatedEvent
        # 4. Triggering audit and metrics handlers
        @post = service.create_post(post_params.merge(user_id: current_user.id))

        render json: @post, status: :created
      end

      # PATCH/PUT /api/v1/posts/:id
      def update
        authorize @post, :update?

        service = PostManagement::PostService.new(
          current_user: current_user,
          organization_id: current_organization.id
        )

        # Service publishes PostUpdatedEvent with change tracking
        @post = service.update_post(@post, post_params)

        render json: @post
      end

      # DELETE /api/v1/posts/:id
      def destroy
        authorize @post, :destroy?

        service = PostManagement::PostService.new(
          current_user: current_user,
          organization_id: current_organization.id
        )

        # Service publishes PostDeletedEvent
        service.delete_post(@post)

        head :no_content
      end

      # POST /api/v1/posts/:id/publish
      # Custom action demonstrating change tracking events
      def publish
        authorize @post, :update?

        # Track old state for change tracking
        old_published = @post.published
        old_published_at = @post.published_at

        @post.publish!

        # Publish event with change tracking
        event = PostUpdatedEvent.new(
          event_type: "post.updated",
          aggregate_id: @post.id.to_s,
          aggregate_type: "Post",
          organization_id: current_organization.id.to_s,
          actor_id: current_user.id.to_s,
          actor_email: current_user.email,
          post_id: @post.id.to_s,
          changed_fields: ["published", "published_at"],
          old_values: { "published" => old_published, "published_at" => old_published_at },
          new_values: { "published" => true, "published_at" => @post.published_at.iso8601 }
        )

        SmartDomain::Event.bus.publish(event)

        render json: @post
      end

      # POST /api/v1/posts/:id/unpublish
      def unpublish
        authorize @post, :update?

        old_published = @post.published
        old_published_at = @post.published_at

        @post.unpublish!

        # Publish event with change tracking
        event = PostUpdatedEvent.new(
          event_type: "post.updated",
          aggregate_id: @post.id.to_s,
          aggregate_type: "Post",
          organization_id: current_organization.id.to_s,
          actor_id: current_user.id.to_s,
          actor_email: current_user.email,
          post_id: @post.id.to_s,
          changed_fields: ["published", "published_at"],
          old_values: { "published" => old_published, "published_at" => old_published_at&.iso8601 },
          new_values: { "published" => false, "published_at" => nil }
        )

        SmartDomain::Event.bus.publish(event)

        render json: @post
      end

      private

      def set_post
        @post = SmartDomain::Integration::TenantContext.with_tenant(current_organization.id) do
          Post.find(params[:id])
        end
      end

      def post_params
        params.require(:post).permit(:title, :body, :published)
      end

      def authorize(post, action)
        policy = PostPolicy.new(current_user, post)
        unless policy.public_send(action)
          raise SmartDomain::Domain::Exceptions::UnauthorizedError, "Not authorized to #{action} this post"
        end
      end
    end
  end
end

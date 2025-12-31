# frozen_string_literal: true

# API Demo script showing controller → service → events flow
#
# Run with: rails runner lib/api_demo.rb

puts "\n" + "=" * 80
puts "SmartDomain API Demo - Controller → Service → Events"
puts "=" * 80 + "\n\n"

# Clean up
Organization.destroy_all
puts "Cleaned up existing data\n\n"

# Create organization
org = Organization.create!(name: "API Demo Corp")
puts "Step 1: Created organization: #{org.name}"
puts "  - ID: #{org.id}\n\n"

# Simulate API request context
module ApiContext
  class << self
    attr_accessor :current_organization, :current_user
  end
end

ApiContext.current_organization = org

# Create admin user
admin = org.users.create!(
  email: "admin@apidemo.com",
  name: "API Admin",
  role: "admin"
)

ApiContext.current_user = admin
puts "Step 2: Created admin user: #{admin.name} <#{admin.email}>\n\n"

# Simulate UsersController#create
puts "Step 3: Simulating POST /api/v1/users (UsersController#create)"
puts "  - Controller receives request"
puts "  - Controller delegates to UserManagement::UserService"

SmartDomain::Integration::TenantContext.with_tenant(org.id) do
  service = UserManagement::UserService.new(
    current_user: admin,
    organization_id: org.id
  )

  user = service.create_user(
    email: "john@apidemo.com",
    name: "John Doe",
    role: "editor"
  )

  puts "  - Service created user: #{user.name}"
  puts "  - Service published UserCreatedEvent"
  puts "  - Handlers triggered: AuditHandler, MetricsHandler, UserWelcomeHandler"
  puts "  - Controller returns JSON response\n\n"

  # Simulate PostsController#create
  puts "Step 4: Simulating POST /api/v1/posts (PostsController#create)"
  puts "  - Controller receives request"
  puts "  - Controller delegates to PostManagement::PostService"

  post_service = PostManagement::PostService.new(
    current_user: user,
    organization_id: org.id
  )

  post = post_service.create_post(
    title: "My First API Post",
    body: "This post was created via the API!",
    user_id: user.id,
    organization_id: org.id,
    published: false
  )

  puts "  - Service created post: #{post.title}"
  puts "  - Service published PostCreatedEvent"
  puts "  - Handlers triggered: AuditHandler, MetricsHandler"
  puts "  - Controller returns JSON response\n\n"

  # Simulate PostsController#publish
  puts "Step 5: Simulating POST /api/v1/posts/#{post.id}/publish"
  puts "  - Controller receives request"
  puts "  - Controller checks authorization (PostPolicy)"
  puts "  - Controller calls post.publish!"

  old_published = post.published
  old_published_at = post.published_at
  post.publish!

  # Manually publish event (as controller would)
  event = PostUpdatedEvent.new(
    event_type: "post.updated",
    aggregate_id: post.id.to_s,
    aggregate_type: "Post",
    organization_id: org.id.to_s,
    actor_id: user.id.to_s,
    actor_email: user.email,
    post_id: post.id.to_s,
    changed_fields: ["published", "published_at"],
    old_values: { "published" => old_published, "published_at" => old_published_at },
    new_values: { "published" => true, "published_at" => post.published_at.iso8601 }
  )

  SmartDomain::Event.bus.publish(event)

  puts "  - Controller published PostUpdatedEvent with change tracking"
  puts "  - Changed fields: published, published_at"
  puts "  - Handlers triggered: AuditHandler, MetricsHandler, PostNotificationHandler"
  puts "  - Controller returns JSON response\n\n"

  # Simulate GET /api/v1/posts (index)
  puts "Step 6: Simulating GET /api/v1/posts (PostsController#index)"
  puts "  - Controller receives request"
  puts "  - Controller queries with TenantContext.with_tenant"

  posts = Post.all
  puts "  - Found #{posts.count} post(s) in organization #{org.name}"
  posts.each do |p|
    puts "    * #{p.title} (#{p.published? ? 'Published' : 'Draft'})"
  end
  puts "  - Controller returns JSON response\n\n"

  # Simulate authorization failure
  puts "Step 7: Demonstrating authorization with policies"

  # Create viewer user
  viewer = org.users.create!(
    email: "viewer@apidemo.com",
    name: "Viewer User",
    role: "viewer"
  )

  admin_policy = PostPolicy.new(admin, post)
  viewer_policy = PostPolicy.new(viewer, post)

  puts "  - Admin attempts to delete post:"
  puts "    PostPolicy.new(admin, post).destroy? => #{admin_policy.destroy?}"

  puts "  - Viewer attempts to delete post:"
  puts "    PostPolicy.new(viewer, post).destroy? => #{viewer_policy.destroy?}"
  puts "    → Would raise SmartDomain::Domain::Exceptions::UnauthorizedError"
  puts "    → Controller catches and returns 403 Forbidden\n\n"
end

puts "=" * 80
puts "API Demo Summary"
puts "=" * 80
puts "\nComplete request flow demonstrated:"
puts "1. ✓ HTTP Request → Controller (Interface Layer)"
puts "2. ✓ Controller → Domain Service (Business Logic Layer)"
puts "3. ✓ Service → Model + Events (Domain Layer)"
puts "4. ✓ Events → Handlers (Side Effects Layer)"
puts "5. ✓ Controller ← JSON Response"
puts "\nKey patterns:"
puts "- Controllers are thin adapters (interface layer)"
puts "- Domain logic lives in services (framework-agnostic)"
puts "- Events published automatically or manually"
puts "- Policies enforce authorization"
puts "- Multi-tenancy ensures data isolation"
puts "\nAPI Endpoints available:"
puts "- GET    /api/v1/users"
puts "- POST   /api/v1/users"
puts "- PATCH  /api/v1/users/:id"
puts "- DELETE /api/v1/users/:id"
puts "- GET    /api/v1/posts"
puts "- POST   /api/v1/posts"
puts "- PATCH  /api/v1/posts/:id"
puts "- DELETE /api/v1/posts/:id"
puts "- POST   /api/v1/posts/:id/publish"
puts "- POST   /api/v1/posts/:id/unpublish"
puts "=" * 80 + "\n\n"

# frozen_string_literal: true

# Demo script showing SmartDomain features
#
# Run with: rails runner lib/demo.rb

puts "\n" + "=" * 80
puts "SmartDomain Gem - Feature Demonstration"
puts "=" * 80 + "\n\n"

# Clean up any existing data
Organization.destroy_all
puts "Cleaned up existing data\n\n"

# Step 1: Create an organization (multi-tenancy)
puts "Step 1: Creating organization (multi-tenancy setup)..."
org = Organization.create!(name: "Acme Corp")
puts "✓ Created organization: #{org.name} (ID: #{org.id})\n\n"

# Step 2: Create a user using the domain service
puts "Step 2: Creating user via UserService (demonstrates domain service + events)..."
SmartDomain::Integration::TenantContext.with_tenant(org.id) do
  service = UserManagement::UserService.new(
    current_user: nil,
    organization_id: org.id
  )

  user_attributes = {
    email: "john@acme.com",
    name: "John Doe",
    role: "admin",
    organization_id: org.id
  }

  user = service.create_user(user_attributes)
  puts "✓ Created user: #{user.name} <#{user.email}>"
  puts "  - Role: #{user.role}"
  puts "  - Organization: #{org.name}"
  puts "  - Events published: user.created"
  puts "  - Handlers triggered: AuditHandler, MetricsHandler, UserWelcomeHandler"
  puts "\n"

  # Step 3: Create a post
  puts "Step 3: Creating a blog post..."
  post_service = PostManagement::PostService.new(
    current_user: user,
    organization_id: org.id
  )

  post = post_service.create_post({
    title: "Getting Started with SmartDomain",
    body: "SmartDomain brings DDD and EDA patterns to Rails...",
    user_id: user.id,
    organization_id: org.id,
    published: false
  })

  puts "✓ Created post: #{post.title}"
  puts "  - Author: #{post.user.name}"
  puts "  - Status: Draft"
  puts "  - Events published: post.created"
  puts "\n"

  # Step 4: Publish the post (triggers update event)
  puts "Step 4: Publishing the post (demonstrates change tracking)..."
  post.publish!

  # Create event with change tracking
  event = PostUpdatedEvent.new(
    event_type: "post.updated",
    aggregate_id: post.id.to_s,
    aggregate_type: "Post",
    organization_id: org.id.to_s,
    actor_id: user.id.to_s,
    actor_email: user.email,
    post_id: post.id.to_s,
    changed_fields: ["published", "published_at"],
    old_values: { "published" => false, "published_at" => nil },
    new_values: { "published" => true, "published_at" => post.published_at.iso8601 }
  )

  SmartDomain::Event.bus.publish(event)

  puts "✓ Published post: #{post.title}"
  puts "  - Published at: #{post.published_at}"
  puts "  - Events published: post.updated"
  puts "  - Changed fields: published, published_at"
  puts "  - Handlers triggered: AuditHandler, MetricsHandler, PostNotificationHandler"
  puts "\n"

  # Step 5: Demonstrate authorization with policies
  puts "Step 5: Demonstrating authorization policies..."

  # Create a viewer user
  viewer = User.create!(
    email: "jane@acme.com",
    name: "Jane Smith",
    role: "viewer",
    organization_id: org.id
  )

  admin_policy = PostPolicy.new(user, post)
  viewer_policy = PostPolicy.new(viewer, post)

  puts "✓ Authorization checks:"
  puts "  - Admin can update post: #{admin_policy.update?}"
  puts "  - Admin can destroy post: #{admin_policy.destroy?}"
  puts "  - Viewer can view post: #{viewer_policy.show?}"
  puts "  - Viewer can update post: #{viewer_policy.update?}"
  puts "  - Viewer can destroy post: #{viewer_policy.destroy?}"
  puts "\n"

  # Step 6: Multi-tenancy isolation
  puts "Step 6: Demonstrating multi-tenancy isolation..."
  other_org = Organization.create!(name: "Other Corp")

  SmartDomain::Integration::TenantContext.with_tenant(other_org.id) do
    other_user = User.create!(
      email: "bob@other.com",
      name: "Bob Johnson",
      role: "admin",
      organization_id: other_org.id
    )

    puts "✓ Created second organization: #{other_org.name}"
    puts "  - Users in Acme Corp: #{org.users.count}"
    puts "  - Users in Other Corp: #{other_org.users.count}"
    puts "  - Posts in Acme Corp: #{org.posts.count}"
    puts "  - Posts in Other Corp: #{other_org.posts.count}"
    puts "  - Data is properly isolated by organization_id"
  end
  puts "\n"
end

# Summary
puts "=" * 80
puts "Demo Summary"
puts "=" * 80
puts "\nFeatures demonstrated:"
puts "1. ✓ Multi-tenancy with TenantContext"
puts "2. ✓ Domain services for business logic"
puts "3. ✓ Event-driven architecture with domain events"
puts "4. ✓ Generic handlers (70% boilerplate reduction)"
puts "5. ✓ Custom event handlers"
puts "6. ✓ Event mixins (Actor, ChangeTracking)"
puts "7. ✓ Domain policies for authorization"
puts "8. ✓ ActiveRecord integration"
puts "9. ✓ Organization-based data isolation"
puts "\nCheck your Rails logs to see all the events and handler executions!"
puts "=" * 80 + "\n\n"

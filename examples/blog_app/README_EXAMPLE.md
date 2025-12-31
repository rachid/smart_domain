# SmartDomain Example: Blog Application

This is a complete example Rails application demonstrating all the features of the **SmartDomain** gem.

## What This Example Demonstrates

This blog application showcases how SmartDomain brings Domain-Driven Design (DDD) and Event-Driven Architecture (EDA) patterns to Rails:

1. **Domain Services** - Business logic encapsulated in service objects
2. **Domain Events** - Immutable events with type safety and validation
3. **Event Bus** - Publish-subscribe pattern for event distribution
4. **Generic Handlers** - 70% boilerplate reduction with `register_standard_handlers`
5. **Custom Event Handlers** - Domain-specific handlers for side effects
6. **Event Mixins** - Reusable event attributes (Actor, ChangeTracking, etc.)
7. **Domain Policies** - Pundit-style authorization
8. **Multi-tenancy** - Organization-based data isolation
9. **ActiveRecord Integration** - Transaction-safe event publishing

## Application Structure

This example uses a **domain-centric structure** where all domain-specific files (models, events, handlers, policies) are grouped within each domain directory. This follows Domain-Driven Design (DDD) best practices and the Aeyes architecture pattern.

```
app/
├── domains/
│   ├── user_management/           # User domain (bounded context)
│   │   ├── models/
│   │   │   └── user.rb            # User model with SmartDomain integration
│   │   ├── events/
│   │   │   ├── user_created_event.rb  # User created event
│   │   │   ├── user_updated_event.rb  # User updated event
│   │   │   └── user_deleted_event.rb  # User deleted event
│   │   ├── handlers/
│   │   │   └── user_welcome_handler.rb  # Custom: Send welcome emails
│   │   ├── policies/
│   │   │   └── user_policy.rb     # User authorization
│   │   ├── user_service.rb        # Business logic for users
│   │   └── setup.rb               # Event handler registration
│   │
│   └── post_management/           # Post domain (bounded context)
│       ├── models/
│       │   └── post.rb            # Post model with SmartDomain integration
│       ├── events/
│       │   ├── post_created_event.rb  # Post created event
│       │   ├── post_updated_event.rb  # Post updated event
│       │   └── post_deleted_event.rb  # Post deleted event
│       ├── handlers/
│       │   └── post_notification_handler.rb  # Custom: Notify on publish
│       ├── policies/
│       │   └── post_policy.rb     # Post authorization
│       ├── post_service.rb        # Business logic for posts
│       └── setup.rb               # Event handler registration
│
├── events/
│   └── application_event.rb       # Base event class (shared)
├── handlers/
│   └── .keep
├── policies/
│   └── application_policy.rb      # Base policy class (shared)
└── models/
    ├── organization.rb            # Multi-tenant organization (shared)
    └── application_record.rb      # Base model class (shared)
```

**Key Design Decisions:**

1. **Domain-Centric Organization**: All domain-specific code lives within `app/domains/{domain}/` subdirectories
2. **Shared Base Classes**: Base classes like `ApplicationEvent` and `ApplicationPolicy` remain at the top level since they're shared across domains
3. **Bounded Contexts**: Each domain is a self-contained bounded context with its own models, events, handlers, and policies
4. **Autoloading Configuration**: Rails is configured to autoload from domain subdirectories (see `config/application.rb`)

## Setup Instructions

### 1. Install Dependencies

```bash
cd examples/blog_app
bundle install
```

### 2. Setup Database

```bash
rails db:create db:migrate
```

### 3. Run the Demo Script

```bash
rails runner lib/demo.rb
```

This will run a comprehensive demonstration showing:
- Creating an organization (multi-tenancy)
- Creating users via domain services
- Publishing domain events
- Generic and custom event handlers
- Creating and publishing blog posts
- Authorization with policies
- Multi-tenant data isolation

## Key Features Demonstrated

### 1. Domain Services

Services encapsulate business logic and publish domain events:

```ruby
service = UserManagement::UserService.new(
  current_user: admin,
  organization_id: org.id
)

user = service.create(User, {
  email: "john@example.com",
  name: "John Doe",
  role: "admin"
})
# Automatically publishes UserCreatedEvent
```

### 2. Event Publishing with Mixins

Events use mixins for common attributes:

```ruby
event = UserCreatedEvent.new(
  event_type: "user.created",
  aggregate_id: user.id,
  aggregate_type: "User",
  organization_id: org.id,
  actor_id: current_user.id,           # From ActorMixin
  actor_email: current_user.email,     # From ActorMixin
  user_id: user.id,
  email: user.email
)
```

### 3. Generic Handlers (70% Boilerplate Reduction)

One line registers audit and metrics handlers for all events:

```ruby
# In app/domains/user_management/setup.rb
SmartDomain::Event::Registration.register_standard_handlers(
  domain: 'user',
  events: %w[created updated deleted],
  include_audit: true,
  include_metrics: true
)
# Replaces ~50 lines of manual subscription code!
```

### 4. Custom Event Handlers

Add domain-specific side effects:

```ruby
class UserWelcomeHandler < SmartDomain::Event::Handler
  def can_handle?(event_type)
    event_type == "user.created"
  end

  def handle(event)
    UserMailer.welcome_email(event.user_id).deliver_later
  end
end

# Register in setup.rb
welcome_handler = UserWelcomeHandler.new
SmartDomain::Event.bus.subscribe('user.created', welcome_handler)
```

### 5. Change Tracking

Track what changed in update events:

```ruby
event = PostUpdatedEvent.new(
  event_type: "post.updated",
  aggregate_id: post.id,
  aggregate_type: "Post",
  organization_id: org.id,
  changed_fields: ["published", "published_at"],
  old_values: { "published" => false, "published_at" => nil },
  new_values: { "published" => true, "published_at" => Time.current }
)
```

### 6. Authorization with Policies

Pundit-style policies for domain authorization:

```ruby
class PostPolicy < ApplicationPolicy
  def update?
    user_present? && (
      user.role == "admin" ||
      (user.role == "editor" && owner?)
    )
  end

  def destroy?
    user_present? && user.role == "admin"
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

### 7. Multi-tenancy

Organization-based data isolation:

```ruby
# Set tenant context
SmartDomain::Integration::TenantContext.with_tenant(org.id) do
  # All queries are automatically scoped to this organization
  users = User.all  # Only returns users from org
  posts = Post.all  # Only returns posts from org
end

# Models use TenantScoped mixin
class User < ApplicationRecord
  include SmartDomain::Integration::TenantScoped
  tenant_key :organization_id
end
```

### 8. ActiveRecord Integration

Transaction-safe event publishing:

```ruby
class Post < ApplicationRecord
  include SmartDomain::Integration::ActiveRecord

  after_commit :publish_created_event, on: :create

  def publish_created_event
    event = PostCreatedEvent.new(...)
    add_domain_event(event)
  end
end
# Events only publish after transaction commits!
```

## Event Flow Example

When a user is created through the service:

```
User.create! → UserService.create
    ↓
UserCreatedEvent published
    ↓
    ├─→ AuditHandler          (logs to Rails.logger + audit table)
    ├─→ MetricsHandler         (increments metrics)
    └─→ UserWelcomeHandler     (sends welcome email)
```

All handlers run synchronously in the current thread with error isolation.

## Running Tests

The example app doesn't include tests, but demonstrates patterns you can test:

```ruby
# Test event publishing
expect {
  service.create(User, attributes)
}.to publish_event(UserCreatedEvent)

# Test handlers
handler = UserWelcomeHandler.new
event = UserCreatedEvent.new(...)
expect { handler.handle(event) }.to send_email

# Test policies
policy = PostPolicy.new(user, post)
expect(policy.update?).to be true
```

## Viewing Logs

All events and handler executions are logged. Run the demo and watch the logs:

```bash
rails runner lib/demo.rb | grep -E '\[SmartDomain|User|Post'
```

You'll see:
- Event publications
- Handler subscriptions
- Audit logs
- Metrics increments
- Custom handler executions

## Next Steps

1. **Explore the generated files**: Look at the domain services, events, and policies
2. **Customize the business logic**: Add validation, workflows, or complex rules
3. **Add more handlers**: Create handlers for emails, notifications, webhooks
4. **Try multi-tenancy**: Create multiple organizations and see data isolation
5. **Add authorization**: Use policies in controllers to enforce permissions
6. **Extend events**: Add more mixins like SecurityContextMixin or ReasonMixin

## Learn More

- **Gem Documentation**: ../../README.md
- **SmartDomain GitHub**: https://github.com/rachid/smart_domain
- **Configuration**: config/initializers/smart_domain.rb

## Key Takeaways

1. **Services own business logic**, controllers delegate
2. **Events are immutable** and published after transaction commits
3. **Generic handlers** eliminate 70% of boilerplate code
4. **Custom handlers** enable domain-specific side effects
5. **Policies centralize** authorization logic
6. **Multi-tenancy** is automatic with TenantContext
7. **Everything is type-safe** and validated

This architecture scales from small apps to large platforms while maintaining clean, maintainable code.

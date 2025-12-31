# SmartDomain

**Domain-Driven Design and Event-Driven Architecture for Rails**

SmartDomain brings battle-tested DDD/EDA patterns from platform to Ruby on Rails applications. It provides domain events, an event bus, generic handlers, and Rails generators for rapid domain scaffolding.

## Features

- ✅ **Domain Events** - Immutable domain events with type safety
- ✅ **Event Bus** - Publish-subscribe pattern for decoupled communication
- ✅ **Event Mixins** - Reusable event fields (Actor, Audit, ChangeTracking, SecurityContext, Reason)
- ✅ **Generic Handlers** - 70% boilerplate reduction for audit and metrics
- ✅ **Rails Integration** - Seamless integration with ActiveRecord and Rails ecosystem
- ✅ **Rails Generators** - Scaffold complete domains with one command (coming soon)
- ✅ **Multi-tenancy Support** - Built-in support for multi-tenant applications
- ✅ **Audit Compliance** - Automatic audit logging for compliance requirements

## Why SmartDomain for AI-Augmented Development?

SmartDomain's architecture is uniquely suited for AI-augmented development workflows:

**Reduced Context Windows**
- Domain-driven design creates **loosely coupled bounded contexts**
- Each domain (User, Order, Product) is self-contained with its own services, events, and policies
- AI tools can focus on one domain at a time, drastically reducing context requirements
- Clear boundaries mean AI understands exactly what code is relevant

**Event-Driven Decoupling**
- Events decouple domains from each other
- Changes in one domain don't cascade through the codebase
- AI can modify a single domain without understanding the entire system
- Explicit event contracts make dependencies transparent

**Explicit Patterns**
- Standardized structure (Service → Events → Handlers) makes code predictable
- AI learns the pattern once, applies it everywhere
- Generators scaffold domains with consistent architecture
- Less cognitive load for both humans and AI

**Example: AI Working with SmartDomain**

When an AI needs to add a "suspend user" feature:

```
Traditional monolithic approach:
- AI must understand: User model, callbacks, mailers, notifications, audit logs,
  related models, 15+ files across different layers
- Context window: ~3000 lines of code

SmartDomain approach:
- AI focuses on: UserService (150 lines), UserSuspendedEvent (20 lines)
- Events automatically trigger audit, metrics, emails via handlers
- Context window: ~200 lines of code
- 93% reduction in context requirements
```

**Benefits for Your Development Workflow**
- **Faster iterations** - AI assistants work with smaller, focused contexts
- **Better code quality** - Consistent patterns reduce hallucinations
- **Easier maintenance** - Clear boundaries make changes predictable
- **Natural collaboration** - AI and human developers work with the same mental model

SmartDomain isn't just better architecture—it's architecture optimized for the AI development era.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'smart_domain'
```

And then execute:

```bash
bundle install
```

Run the install generator:

```bash
rails generate smart_domain:install
```

This creates:
- `config/initializers/smart_domain.rb` - Configuration file
- `app/events/application_event.rb` - Base event class
- `app/policies/application_policy.rb` - Base policy class
- `app/services/application_service.rb` - Base service class
- `app/domains/` - Domain directory structure

## Quick Start

### 1. Configure SmartDomain

Create an initializer in `config/initializers/smart_domain.rb`:

```ruby
SmartDomain.configure do |config|
  config.event_bus_adapter = :memory  # or :redis, :active_job
  config.audit_table_enabled = true   # Enable audit table writes
  config.multi_tenancy_enabled = true # Enable multi-tenancy
  config.tenant_key = :organization_id
  config.async_handlers = false       # Use ActiveJob for async handlers
  config.logger = Rails.logger
end
```

### 2. Define Domain Events

```ruby
# app/events/user_created_event.rb
class UserCreatedEvent < SmartDomain::Event::Base
  attribute :user_id, :string
  attribute :email, :string

  validates :user_id, :email, presence: true
end

# app/events/user_updated_event.rb
class UserUpdatedEvent < SmartDomain::Event::Base
  include SmartDomain::Event::ActorMixin          # Who
  include SmartDomain::Event::ChangeTrackingMixin # What changed

  attribute :user_id, :string

  validates :user_id, presence: true
end
```

### 3. Publish Events

```ruby
# In your service or model
user = User.create!(email: 'user@example.com', name: 'John Doe')

event = UserCreatedEvent.new(
  event_type: 'user.created',
  aggregate_id: user.id,
  aggregate_type: 'User',
  organization_id: current_organization.id,
  user_id: user.id,
  email: user.email
)

SmartDomain::Event.bus.publish(event)
```

### 4. Register Event Handlers (The Magic!)

Instead of manually subscribing audit and metrics handlers to each event:

```ruby
# ❌ OLD WAY - Lots of boilerplate
audit = AuditHandler.new('user')
metrics = MetricsHandler.new('user')
SmartDomain::Event.bus.subscribe('user.created', audit)
SmartDomain::Event.bus.subscribe('user.created', metrics)
SmartDomain::Event.bus.subscribe('user.updated', audit)
SmartDomain::Event.bus.subscribe('user.updated', metrics)
# ... repeat for all events ...
```

Use this **one-liner** for 70% boilerplate reduction:

```ruby
# ✅ NEW WAY - One line for all standard handlers
SmartDomain::Event::Registration.register_standard_handlers(
  domain: 'user',
  events: %w[created updated deleted activated suspended],
  include_audit: true,
  include_metrics: true
)
```

### 5. Create Custom Event Handlers

```ruby
# app/handlers/user_email_handler.rb
class UserEmailHandler < SmartDomain::Event::Handler
  def handle(event)
    case event.event_type
    when 'user.created'
      UserMailer.welcome_email(event.user_id).deliver_later
    when 'user.activated'
      UserMailer.account_activated(event.user_id).deliver_later
    end
  end

  def can_handle?(event_type)
    ['user.created', 'user.activated'].include?(event_type)
  end
end

# Register custom handler
email_handler = UserEmailHandler.new
SmartDomain::Event.bus.subscribe('user.created', email_handler)
SmartDomain::Event.bus.subscribe('user.activated', email_handler)
```

## Core Concepts

### Domain Events

Domain events represent significant business occurrences in your application. They are:

- **Immutable** - Once created, events cannot be modified
- **Type-safe** - Uses ActiveModel::Attributes for type coercion
- **Validated** - ActiveModel validations ensure event integrity
- **Structured** - Standardized fields across all events

**Core Event Fields:**
- `event_id` - Unique event identifier (UUID)
- `event_type` - Event type (e.g., 'user.created')
- `aggregate_id` - ID of the entity that produced the event
- `aggregate_type` - Type of entity (e.g., 'User', 'Order')
- `organization_id` - Tenant/organization context
- `occurred_at` - Timestamp when event occurred
- `version` - Event schema version
- `correlation_id` - For tracing related events
- `causation_id` - Event that caused this event
- `metadata` - Additional data

### Event Mixins

Event mixins provide reusable fields for common patterns:

#### ActorMixin - WHO performed the action
```ruby
class UserSuspendedEvent < SmartDomain::Event::Base
  include SmartDomain::Event::ActorMixin

  # Provides: actor_id, actor_email
end
```

#### ChangeTrackingMixin - WHAT changed
```ruby
class UserUpdatedEvent < SmartDomain::Event::Base
  include SmartDomain::Event::ChangeTrackingMixin

  # Provides: changed_fields, old_values, new_values
end

# Usage
event = UserUpdatedEvent.new(
  ...,
  changed_fields: ['email', 'name'],
  old_values: { email: 'old@example.com', name: 'Old Name' },
  new_values: { email: 'new@example.com', name: 'New Name' }
)
```

#### SecurityContextMixin - WHERE from
```ruby
class UserLoggedInEvent < SmartDomain::Event::Base
  include SmartDomain::Event::SecurityContextMixin

  # Provides: ip_address, user_agent
end
```

#### ReasonMixin - WHY
```ruby
class UserBannedEvent < SmartDomain::Event::Base
  include SmartDomain::Event::ReasonMixin

  # Provides: reason
end

event = UserBannedEvent.new(
  ...,
  reason: 'Violation of terms of service - spam activity detected'
)
```

### Event Bus

The event bus follows the **publish-subscribe pattern** for decoupled communication.

**Features:**
- Synchronous by default (in-memory)
- Pluggable adapters (Memory, Redis, ActiveJob)
- Error isolation (handler failures don't affect other handlers)
- Structured logging

### Generic Handlers

Generic handlers provide cross-cutting concerns for all domains:

#### AuditHandler
- Logs all events to Rails logger with structured data
- Optionally writes to audit_events table for compliance
- Categorizes events (authentication, data_access, admin_action, system_event)
- Assesses risk level (HIGH, MEDIUM, LOW)
- Extracts fields from event mixins (actor_id, ip_address, old_values, etc.)

#### MetricsHandler
- Collects metrics from domain events
- Integrates with metrics systems (StatsD, Datadog, Prometheus, CloudWatch)
- Provides metric name and tags for easy querying

### Hybrid Event Approach

The hybrid approach combines explicit event definitions with generic infrastructure:

**Before (70 lines of repetitive code):**
```ruby
class UserAuditHandler < SmartDomain::Event::Handler
  def handle(event)
    # Audit logging logic...
  end
end

class UserMetricsHandler < SmartDomain::Event::Handler
  def handle(event)
    # Metrics logic...
  end
end

# Manual subscription
audit = UserAuditHandler.new
metrics = UserMetricsHandler.new
bus.subscribe('user.created', audit)
bus.subscribe('user.updated', audit)
bus.subscribe('user.created', metrics)
bus.subscribe('user.updated', metrics)
# ... 50 more lines ...
```

**After (1 line with `register_standard_handlers`):**
```ruby
SmartDomain::Event::Registration.register_standard_handlers(
  domain: 'user',
  events: %w[created updated deleted],
  include_audit: true,
  include_metrics: true
)
```

**Result:** 70% less boilerplate, validated in production at Aeyes!

## Architecture Patterns

### Domain-Driven Design (DDD)

SmartDomain encourages organizing code by **bounded contexts** (domains):

```
app/domains/
├── user_management/
│   ├── user_service.rb
│   ├── user_events.rb
│   ├── user_handlers.rb
│   ├── user_policy.rb
│   └── setup.rb
├── order_management/
│   ├── order_service.rb
│   ├── order_events.rb
│   └── setup.rb
└── ...
```

### Event-Driven Architecture (EDA)

**Principles:**
1. **Events are mandatory** - Every significant business action publishes an event
2. **Publish after commit** - Events published after database transaction commits
3. **Cross-domain communication via events** - Domains don't call each other directly
4. **Fire-and-forget** - Event publishing is asynchronous from handling

**Example:**
```ruby
# ✅ GOOD: Publish event
ActiveRecord::Base.transaction do
  user = User.create!(params)
  event = UserCreatedEvent.new(...)

  # Publish AFTER commit
  ActiveRecord::Base.connection.after_transaction_commit do
    SmartDomain::Event.bus.publish(event)
  end
end

# ❌ BAD: Direct cross-domain call
OrderService.cancel_user_orders(user.id) # Tight coupling!
```

## Configuration Options

```ruby
SmartDomain.configure do |config|
  # Event bus adapter (:memory, :redis, :active_job)
  config.event_bus_adapter = :memory

  # Enable automatic writes to audit_events table
  config.audit_table_enabled = true

  # Enable multi-tenancy support
  config.multi_tenancy_enabled = true

  # Key used for tenant identification
  config.tenant_key = :organization_id

  # Use ActiveJob for asynchronous event handling
  config.async_handlers = false

  # Logger instance
  config.logger = Rails.logger
end
```

## Audit Table Schema

If `audit_table_enabled` is true, create an `audit_events` table:

```ruby
create_table :audit_events do |t|
  t.string :event_type, null: false
  t.string :event_category, null: false
  t.bigint :user_id
  t.string :organization_id
  t.string :ip_address
  t.text :user_agent
  t.json :old_values
  t.json :new_values
  t.datetime :occurred_at, null: false
  t.string :risk_level
  t.json :compliance_flags

  t.timestamps

  t.index :event_type
  t.index :event_category
  t.index :user_id
  t.index :organization_id
  t.index :occurred_at
end
```

## Testing

Testing events and handlers is straightforward:

```ruby
# spec/support/event_helpers.rb
module EventHelpers
  def published_events
    @published_events ||= []
  end

  def expect_event(event_type)
    expect(published_events.map(&:event_type)).to include(event_type)
  end

  def stub_event_bus
    allow(SmartDomain::Event.bus).to receive(:publish) do |event|
      published_events << event
    end
  end
end

RSpec.configure do |config|
  config.include EventHelpers

  config.before(:each) do
    @published_events = []
    stub_event_bus
  end
end

# spec/services/user_service_spec.rb
RSpec.describe UserService do
  it 'publishes user.created event' do
    service = UserService.new
    user = service.create_user(email: 'test@example.com')

    expect(user).to be_persisted
    expect_event('user.created')
  end
end
```

## Domain Service Pattern

Domain services encapsulate business logic that doesn't naturally fit within a single entity. They follow these principles:

1. **Services own business logic** - Controllers delegate to services
2. **Services publish events** - After successful operations
3. **Services use transactions** - For data consistency
4. **Services are stateless** - Except for injected context

### Creating a Domain Service

```ruby
# app/services/user_service.rb
class UserService < SmartDomain::Domain::Service
  def create_user(attributes)
    # Validate input
    raise ValidationError.new('Email is required') if attributes[:email].blank?

    User.transaction do
      # Check business rules
      if User.exists?(email: attributes[:email])
        raise AlreadyExistsError.new('User', 'email', attributes[:email])
      end

      # Create entity
      user = User.create!(attributes)

      # Build and publish event
      event = build_event(UserCreatedEvent,
        event_type: 'user.created',
        aggregate_id: user.id,
        aggregate_type: 'User',
        user_id: user.id,
        email: user.email
      )

      publish_after_commit(event)
      user
    end
  end

  def update_user(user_id, attributes)
    user = User.find(user_id)

    # Authorization
    policy = UserPolicy.new(current_user, user)
    authorize!(policy, :update?)

    User.transaction do
      user.update!(attributes)

      # Extract changes for event
      changes = extract_changes(user)

      event = build_event(UserUpdatedEvent,
        event_type: 'user.updated',
        aggregate_id: user.id,
        aggregate_type: 'User',
        user_id: user.id,
        **changes  # Includes changed_fields, old_values, new_values
      )

      publish_after_commit(event)
      user
    end
  end

  def activate_user(user_id)
    user = User.find(user_id)

    # Business rule validation
    unless user.pending?
      raise InvalidStateError.new('User',
        from: user.status,
        to: 'active',
        reason: 'User must be pending to activate'
      )
    end

    User.transaction do
      user.update!(status: 'active')

      event = build_event(UserActivatedEvent,
        event_type: 'user.activated',
        aggregate_id: user.id,
        aggregate_type: 'User',
        user_id: user.id
      )

      publish_after_commit(event)
      user
    end
  end
end
```

### Using Services in Controllers

```ruby
class UsersController < ApplicationController
  def create
    service = UserService.new(
      current_user: current_user,
      organization_id: current_organization.id
    )

    @user = service.create_user(user_params)
    redirect_to @user, notice: 'User created successfully'
  rescue SmartDomain::Domain::ValidationError => e
    flash[:error] = e.message
    render :new
  rescue SmartDomain::Domain::AlreadyExistsError => e
    flash[:error] = e.message
    render :new
  end

  def update
    service = UserService.new(current_user: current_user)
    @user = service.update_user(params[:id], user_params)
    redirect_to @user, notice: 'User updated successfully'
  rescue SmartDomain::Domain::UnauthorizedError
    redirect_to root_path, alert: 'You are not authorized to perform this action'
  end
end
```

### Service Helper Methods

The `Domain::Service` base class provides several helper methods:

#### `build_event(event_class, attributes)`
Automatically fills in `organization_id` and actor fields from service context:

```ruby
event = build_event(UserCreatedEvent,
  event_type: 'user.created',
  aggregate_id: user.id,
  aggregate_type: 'User',
  user_id: user.id,
  email: user.email
  # organization_id, actor_id, actor_email filled automatically!
)
```

#### `extract_changes(record)`
Extracts changed fields from ActiveRecord model for ChangeTrackingMixin:

```ruby
user.update!(email: 'new@example.com')
changes = extract_changes(user)
# => {
#   changed_fields: ['email'],
#   old_values: { email: 'old@example.com' },
#   new_values: { email: 'new@example.com' }
# }
```

#### `authorize!(policy, action)`
Check authorization and raise error if not authorized:

```ruby
policy = UserPolicy.new(current_user, user)
authorize!(policy, :update?)  # Raises UnauthorizedError if not allowed
```

#### `with_transaction(&block)`
Wrap operations in a database transaction:

```ruby
with_transaction do
  user = User.create!(attributes)
  profile = Profile.create!(user: user, ...)
  publish_after_commit(UserCreatedEvent.new(...))
end
```

#### `log(level, message, data = {})`
Log with service context:

```ruby
log(:info, 'User created', user_id: user.id, email: user.email)
```

## Domain Exceptions

SmartDomain provides a hierarchy of domain exceptions for business rule violations:

```ruby
# Base exception
SmartDomain::Domain::Error

# Specific exceptions
SmartDomain::Domain::NotFoundError.new('User', user_id)
SmartDomain::Domain::AlreadyExistsError.new('User', 'email', email)
SmartDomain::Domain::BusinessRuleError.new('Cannot delete user with active orders')
SmartDomain::Domain::InvalidStateError.new('User', from: 'suspended', to: 'active')
SmartDomain::Domain::ValidationError.new('Validation failed', errors: { email: ['is required'] })
SmartDomain::Domain::UnauthorizedError.new('Not authorized')
SmartDomain::Domain::DependencyError.new('Redis')
```

All exceptions support structured error details:

```ruby
begin
  service.create_user(params)
rescue SmartDomain::Domain::AlreadyExistsError => e
  render json: e.to_h, status: :unprocessable_entity
  # => {
  #   error: "SmartDomain::Domain::AlreadyExistsError",
  #   message: "User with email 'test@example.com' already exists",
  #   code: :already_exists,
  #   details: {
  #     entity_type: "User",
  #     attribute: "email",
  #     value: "test@example.com"
  #   }
  # }
end
```

## Domain Policies (Authorization)

Domain policies encapsulate authorization logic (similar to Pundit):

```ruby
# app/policies/user_policy.rb
class UserPolicy < SmartDomain::Domain::Policy
  def create?
    user.admin? || user.manager?
  end

  def update?
    user.admin? || owner?
  end

  def destroy?
    user.admin? && record.id != user.id
  end

  def activate?
    user.admin? && record.pending?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(organization_id: user.organization_id)
      end
    end
  end
end

# Usage in service
policy = UserPolicy.new(current_user, user)
authorize!(policy, :update?)  # Raises UnauthorizedError if false

# Usage in controller (for index)
@users = policy_scope(User.all, UserPolicy)
```

## ActiveRecord Integration

SmartDomain provides seamless integration with ActiveRecord for publishing domain events directly from models.

### Including in Models

```ruby
class User < ApplicationRecord
  include SmartDomain::Integration::ActiveRecord

  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_deleted_event

  private

  def publish_created_event
    event = build_domain_event(UserCreatedEvent,
      event_type: 'user.created',
      user_id: id,
      email: email
    )
    add_domain_event(event)
  end

  def publish_updated_event
    return if saved_changes.empty?

    changes = domain_event_changes

    event = build_domain_event(UserUpdatedEvent,
      event_type: 'user.updated',
      user_id: id,
      **changes  # changed_fields, old_values, new_values
    )
    add_domain_event(event)
  end

  def publish_deleted_event
    event = build_domain_event(UserDeletedEvent,
      event_type: 'user.deleted',
      user_id: id,
      email: email
    )
    add_domain_event(event)
  end
end
```

### How It Works

1. **Events are queued** during callbacks (after_create, after_update, etc.)
2. **Events are published** AFTER the database transaction commits
3. **If transaction rolls back**, events are automatically discarded
4. **Thread-safe** - Each model instance has its own event queue

### Helper Methods

#### `add_domain_event(event)`
Queue an event for publishing after commit:

```ruby
event = UserCreatedEvent.new(...)
add_domain_event(event)
```

#### `build_domain_event(event_class, attributes)`
Build an event with automatic field population:

```ruby
# Automatically fills: aggregate_id, aggregate_type, organization_id
event = build_domain_event(UserCreatedEvent,
  event_type: 'user.created',
  user_id: id,
  email: email
)
```

#### `domain_event_changes`
Extract changes for ChangeTrackingMixin:

```ruby
user.update!(email: 'new@example.com')

changes = user.domain_event_changes
# => {
#   changed_fields: ['email', 'updated_at'],
#   old_values: { email: 'old@example.com', ... },
#   new_values: { email: 'new@example.com', ... }
# }
```

### Transaction Safety

Events are **only published if the transaction succeeds**:

```ruby
User.transaction do
  user = User.create!(email: 'test@example.com')
  # Event queued, not published yet

  raise ActiveRecord::Rollback  # Transaction rolls back
  # Event is discarded
end
# No event published!

User.transaction do
  user = User.create!(email: 'test@example.com')
  # Event queued
end  # Transaction commits
# UserCreatedEvent published!
```

### Nested Transactions

Works correctly with nested transactions:

```ruby
User.transaction do
  user = User.create!(email: 'test@example.com')

  User.transaction(requires_new: true) do
    profile = Profile.create!(user: user)
    # Both events queued
  end  # Inner transaction commits

end  # Outer transaction commits
# Both events published here
```

## Multi-Tenancy Support

SmartDomain provides built-in multi-tenancy support with thread-safe tenant context.

### Setting Up Multi-Tenancy

```ruby
# config/initializers/smart_domain.rb
SmartDomain.configure do |config|
  config.multi_tenancy_enabled = true
  config.tenant_key = :organization_id  # Your tenant column name
end
```

### Controller Integration

```ruby
class ApplicationController < ActionController::Base
  around_action :set_current_tenant

  private

  def set_current_tenant
    SmartDomain::Integration::TenantContext.with_tenant(current_organization.id) do
      yield
    end
  end
end
```

### Automatic Tenant Assignment

```ruby
class User < ApplicationRecord
  include SmartDomain::Integration::TenantScoped

  # organization_id will be automatically set from TenantContext.current
end

# In controller
SmartDomain::Integration::TenantContext.with_tenant('org-123') do
  user = User.create!(email: 'test@example.com')
  # user.organization_id => 'org-123'
end
```

### Tenant Context API

```ruby
# Get current tenant
tenant_id = SmartDomain::Integration::TenantContext.current

# Set current tenant
SmartDomain::Integration::TenantContext.current = 'org-123'

# Execute within tenant context
SmartDomain::Integration::TenantContext.with_tenant('org-123') do
  # All operations use org-123 as tenant
end

# Check if tenant is set
SmartDomain::Integration::TenantContext.tenant_set?  # => true/false

# Clear tenant
SmartDomain::Integration::TenantContext.clear!
```

## Complete Example

Here's a complete example combining all features:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include SmartDomain::Integration::ActiveRecord
  include SmartDomain::Integration::TenantScoped

  validates :email, presence: true, uniqueness: true

  after_create :publish_created_event
  after_update :publish_updated_event

  private

  def publish_created_event
    event = build_domain_event(UserCreatedEvent,
      event_type: 'user.created',
      user_id: id,
      email: email
    )
    add_domain_event(event)
  end

  def publish_updated_event
    return if saved_changes.empty?

    event = build_domain_event(UserUpdatedEvent,
      event_type: 'user.updated',
      user_id: id,
      **domain_event_changes
    )
    add_domain_event(event)
  end
end

# app/events/user_created_event.rb
class UserCreatedEvent < SmartDomain::Event::Base
  include SmartDomain::Event::ActorMixin

  attribute :user_id, :string
  attribute :email, :string

  validates :user_id, :email, presence: true
end

# app/events/user_updated_event.rb
class UserUpdatedEvent < SmartDomain::Event::Base
  include SmartDomain::Event::ActorMixin
  include SmartDomain::Event::ChangeTrackingMixin

  attribute :user_id, :string

  validates :user_id, presence: true
end

# app/services/user_service.rb
class UserService < SmartDomain::Domain::Service
  def create_user(attributes)
    # Validation
    if User.exists?(email: attributes[:email])
      raise SmartDomain::Domain::AlreadyExistsError.new('User', 'email', attributes[:email])
    end

    # Create user (events published automatically)
    User.create!(attributes)
  end

  def update_user(user_id, attributes)
    user = User.find(user_id)

    # Authorization
    policy = UserPolicy.new(current_user, user)
    authorize!(policy, :update?)

    # Update user (events published automatically)
    user.update!(attributes)
    user
  end
end

# config/initializers/smart_domain.rb
SmartDomain.configure do |config|
  config.event_bus_adapter = :memory
  config.audit_table_enabled = true
  config.multi_tenancy_enabled = true
  config.tenant_key = :organization_id
  config.logger = Rails.logger
end

# Setup event handlers
SmartDomain::Event::Registration.register_standard_handlers(
  domain: 'user',
  events: %w[created updated deleted],
  include_audit: true,
  include_metrics: true
)

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  around_action :set_current_tenant

  def create
    service = UserService.new(
      current_user: current_user,
      organization_id: current_organization.id
    )

    @user = service.create_user(user_params)
    redirect_to @user, notice: 'User created successfully'
  rescue SmartDomain::Domain::AlreadyExistsError => e
    flash[:error] = e.message
    render :new
  end

  private

  def set_current_tenant
    SmartDomain::Integration::TenantContext.with_tenant(current_organization.id) do
      yield
    end
  end
end
```

## Rails Generators

SmartDomain provides powerful generators to scaffold complete domains with one command.

### Install Generator

```bash
rails generate smart_domain:install
```

Creates the initial SmartDomain structure in your Rails app:
- Configuration initializer
- Base classes (ApplicationEvent, ApplicationPolicy, ApplicationService)
- Directory structure (app/domains/, app/events/, app/handlers/, app/policies/)

### Domain Generator

```bash
rails generate smart_domain:domain User
```

Generates a complete domain structure:

```
app/domains/user_management/
  user_service.rb         # Business logic
  setup.rb                # Event handler registration

app/events/
  user_created_event.rb   # Created event
  user_updated_event.rb   # Updated event (with ChangeTrackingMixin)
  user_deleted_event.rb   # Deleted event

app/policies/
  user_policy.rb          # Authorization rules
```

**Generated Service** (`app/domains/user_management/user_service.rb`):
- Complete CRUD operations (create, update, delete, list)
- Authorization checks
- Event publishing
- Business rule validation examples
- Policy scoping

**Generated Events** (`app/events/user_*_event.rb`):
- UserCreatedEvent with ActorMixin
- UserUpdatedEvent with ActorMixin + ChangeTrackingMixin
- UserDeletedEvent with ActorMixin

**Generated Policy** (`app/policies/user_policy.rb`):
- Authorization rules (index?, show?, create?, update?, destroy?)
- Scope class for index queries
- Helper methods (admin?, owner?, same_organization?)

**Generated Setup** (`app/domains/user_management/setup.rb`):
- Automatic event handler registration
- One-line registration for audit and metrics handlers
- Examples for custom handlers

### Generator Options

```bash
# Skip specific files
rails generate smart_domain:domain Order --skip-service
rails generate smart_domain:domain Product --skip-policy
rails generate smart_domain:domain Invoice --skip-events

# Generate minimal domain
rails generate smart_domain:domain Report --skip-service --skip-policy
```

### Rake Tasks

```bash
# List all registered domains
rake smart_domain:domains

# Reload domain setups
rake smart_domain:reload
```

### Example Workflow

```bash
# 1. Install SmartDomain
rails generate smart_domain:install

# 2. Generate your first domain
rails generate smart_domain:domain User

# 3. Create the User model
rails generate model User email:string name:string organization:references

# 4. Add SmartDomain integration to the model
# In app/models/user.rb:
class User < ApplicationRecord
  include SmartDomain::Integration::ActiveRecord
  include SmartDomain::Integration::TenantScoped

  after_create :publish_created_event
  after_update :publish_updated_event

  private

  def publish_created_event
    event = build_domain_event(UserCreatedEvent,
      event_type: 'user.created',
      user_id: id,
      email: email
    )
    add_domain_event(event)
  end

  def publish_updated_event
    return if saved_changes.empty?

    event = build_domain_event(UserUpdatedEvent,
      event_type: 'user.updated',
      user_id: id,
      **domain_event_changes
    )
    add_domain_event(event)
  end
end

# 5. Use the service in your controller
class UsersController < ApplicationController
  def create
    service = UserManagement::UserService.new(
      current_user: current_user,
      organization_id: current_organization.id
    )

    @user = service.create_user(user_params)
    redirect_to @user, notice: 'User created successfully'
  rescue SmartDomain::Domain::AlreadyExistsError => e
    flash[:error] = e.message
    render :new
  end
end

# 6. Restart Rails to load domain setup
rails restart
```

## Roadmap

- [x] Core event system (Base, Bus, Mixins, Handlers)
- [x] Generic handlers (Audit, Metrics)
- [x] Event registration helper (70% boilerplate reduction)
- [x] Configuration DSL
- [x] Domain service pattern
- [x] Domain exceptions
- [x] Domain policies (authorization)
- [x] ActiveRecord integration (after_commit hooks)
- [x] Multi-tenancy support
- [x] Rails generators (`rails g smart_domain:domain User`)
- [x] Railtie for automatic setup
- [x] Rake tasks (list domains, reload setups)
- [ ] Redis adapter
- [ ] ActiveJob adapter
- [ ] Example Rails application
- [ ] Comprehensive test suite
- [ ] Documentation site

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rachid/smart_domain.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

**Architecture designed and battle-tested by:**
- Rachid Al Maach (@rachid)

**Influenced by:**
- Domain-Driven Design (Eric Evans)
- Event-Driven Architecture patterns
- Rails Event Store
- Healthcare platform architecture

## Support

For questions, issues, or feature requests, please:
1. Check the documentation
2. Search existing GitHub issues
3. Create a new issue with detailed information

---

**Last Updated:** 2025-12-29
**Version:** 0.1.0
**Status:** Alpha - Core features implemented, generators and Rails integration coming soon

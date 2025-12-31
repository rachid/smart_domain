# frozen_string_literal: true

require "active_support/concern"

module SmartDomain
  module Event
    # Reusable mixins for domain events to reduce boilerplate.
    #
    # These mixins provide common event fields following the pattern:
    # - WHO performed the action (ActorMixin)
    # - WHEN it occurred (AuditMixin)
    # - WHAT changed (ChangeTrackingMixin)
    # - WHERE from (SecurityContextMixin)
    # - WHY (ReasonMixin)
    #
    # @example Using mixins in an event
    #   class UserUpdatedEvent < SmartDomain::Event::Base
    #     include SmartDomain::Event::ActorMixin
    #     include SmartDomain::Event::ChangeTrackingMixin
    #
    #     attribute :user_id, :string
    #   end

    # Mixin for tracking WHO performed the action
    #
    # Adds actor_id and actor_email fields to track which user
    # triggered the event.
    #
    # @example
    #   class UserCreatedEvent < SmartDomain::Event::Base
    #     include SmartDomain::Event::ActorMixin
    #   end
    #
    #   event = UserCreatedEvent.new(
    #     ...,
    #     actor_id: current_user.id,
    #     actor_email: current_user.email
    #   )
    module ActorMixin
      extend ActiveSupport::Concern

      included do
        attribute :actor_id, :string
        attribute :actor_email, :string

        validates :actor_id, presence: true
      end
    end

    # Mixin for tracking WHEN the action occurred
    #
    # Adds occurred_at timestamp field. This is usually redundant with
    # the base event class but can be included for explicit tracking.
    #
    # @example
    #   class PaymentProcessedEvent < SmartDomain::Event::Base
    #     include SmartDomain::Event::AuditMixin
    #   end
    module AuditMixin
      extend ActiveSupport::Concern

      included do
        attribute :occurred_at, :datetime, default: -> { Time.current }
      end
    end

    # Mixin for tracking WHAT changed in an update event
    #
    # Adds fields for tracking field-level changes:
    # - changed_fields: Array of field names that changed
    # - old_values: Hash of field => old value
    # - new_values: Hash of field => new value
    #
    # @example
    #   class UserUpdatedEvent < SmartDomain::Event::Base
    #     include SmartDomain::Event::ChangeTrackingMixin
    #   end
    #
    #   event = UserUpdatedEvent.new(
    #     ...,
    #     changed_fields: ['email', 'name'],
    #     old_values: { email: 'old@example.com', name: 'Old Name' },
    #     new_values: { email: 'new@example.com', name: 'New Name' }
    #   )
    module ChangeTrackingMixin
      extend ActiveSupport::Concern

      included do
        attribute :changed_fields, default: -> { [] }
        attribute :old_values, default: -> { {} }
        attribute :new_values, default: -> { {} }

        validate :changed_fields_must_not_be_empty

        private

        def changed_fields_must_not_be_empty
          errors.add(:changed_fields, "can't be blank") if changed_fields.blank? || changed_fields.empty?
        end
      end

      # Helper to extract changes from an ActiveRecord model
      # @param record [ActiveRecord::Base] Record with changes
      # @return [Hash] Hash with changed_fields, old_values, new_values
      def self.changes_from(record)
        return { changed_fields: [], old_values: {}, new_values: {} } unless record.respond_to?(:saved_changes)

        changes = record.saved_changes
        {
          changed_fields: changes.keys,
          old_values: changes.transform_values(&:first),
          new_values: changes.transform_values(&:last)
        }
      end
    end

    # Mixin for tracking WHERE the action came from
    #
    # Adds security context fields:
    # - ip_address: IP address of the request
    # - user_agent: User agent string from the request
    #
    # @example
    #   class UserLoggedInEvent < SmartDomain::Event::Base
    #     include SmartDomain::Event::SecurityContextMixin
    #   end
    #
    #   event = UserLoggedInEvent.new(
    #     ...,
    #     ip_address: request.remote_ip,
    #     user_agent: request.user_agent
    #   )
    module SecurityContextMixin
      extend ActiveSupport::Concern

      included do
        attribute :ip_address, :string
        attribute :user_agent, :string
      end
    end

    # Mixin for tracking WHY an action was performed
    #
    # Adds a reason field for documenting why an administrative
    # action was taken.
    #
    # @example
    #   class UserSuspendedEvent < SmartDomain::Event::Base
    #     include SmartDomain::Event::ReasonMixin
    #   end
    #
    #   event = UserSuspendedEvent.new(
    #     ...,
    #     reason: 'Violation of terms of service - spam activity detected'
    #   )
    module ReasonMixin
      extend ActiveSupport::Concern

      included do
        attribute :reason, :string

        validates :reason, presence: true
      end
    end
  end
end

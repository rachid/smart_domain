# frozen_string_literal: true

# Custom event handler for notifying subscribers when posts are published
#
# This handler demonstrates conditional handling based on event data.
class PostNotificationHandler < SmartDomain::Event::Handler
  def can_handle?(event_type)
    event_type == "post.updated"
  end

  def handle(event)
    # Only send notifications if the post was just published
    if post_was_published?(event)
      Rails.logger.info "[PostNotificationHandler] Post '#{event.post_id}' was published!"
      Rails.logger.info "[PostNotificationHandler] Would notify subscribers here"

      # In a real application, this would:
      # - Find all subscribers
      # - Send push notifications
      # - Send email digests
      # - Update RSS feeds
    end
  end

  private

  def post_was_published?(event)
    # Check if 'published' changed from false to true
    event.respond_to?(:changed_fields) &&
      event.changed_fields.include?("published") &&
      event.new_values["published"] == true
  end
end

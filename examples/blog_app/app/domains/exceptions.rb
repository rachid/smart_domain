# frozen_string_literal: true

module SmartDomain
  module Domain
    module Exceptions
      # Base domain exception
      class DomainError < StandardError; end

      # Authorization error
      class UnauthorizedError < DomainError; end

      # Validation error
      class ValidationError < DomainError; end

      # Not found error
      class NotFoundError < DomainError; end
    end
  end
end

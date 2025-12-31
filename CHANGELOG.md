# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2025-12-31

### Added
- Comprehensive RuboCop configuration for code quality enforcement
- ValidationError class for proper event validation error handling
- Mixin validations (ChangeTrackingMixin requires changed_fields, ReasonMixin requires reason)
- Logger configuration support in Memory adapter and Bus

### Fixed
- All test failures - achieved 100% test pass rate (90 examples, 0 failures)
- Event validation error handling with proper ValidationError exceptions
- Handler error messages to match standard Ruby conventions
- Audit handler database schema to match actual audit_events table structure
- Metrics handler to support timing metrics for events with duration
- 926 RuboCop style violations for consistent code quality

### Changed
- Updated audit handler to write correct event data to database
- Improved error handling across event system components
- Converted all double-quoted strings to single quotes (Ruby style)
- Improved hash alignment and code formatting throughout codebase

## [0.1.1] - 2025-12-31

### Changed
- Enhanced README with AI-augmented development advantages section
- Explained how DDD/EDA architecture reduces context windows by 93%
- Added concrete examples of reduced cognitive load for AI assistants

## [0.1.0] - 2025-12-29

### Added
- Initial release
- Core event-driven architecture
- Domain-Driven Design patterns
- Rails integration

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`ses_dashboard` is a **mountable Rails engine gem** that provides a real-time dashboard for Amazon SES. It tracks email delivery, bounces, complaints, opens, and clicks via SNS webhooks with pluggable authentication adapters.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/models/ses_dashboard/email_spec.rb

# Run a single example by line number
bundle exec rspec spec/models/ses_dashboard/email_spec.rb:15

# Run tests by directory
bundle exec rspec spec/controllers

# Run all tests in Docker (includes system specs with Selenium Chrome)
docker compose run --rm app bundle exec rspec

# Run only system specs (requires Docker for Chrome)
docker compose run --rm app bundle exec rspec spec/system
```

System specs require Docker Compose — they use a remote Selenium Chrome container. Unit and controller specs run locally without Docker.

## Architecture

### Engine structure

- **`lib/ses_dashboard/`** — Core library code (no ActiveRecord dependency):
  - `client.rb` — AWS SES SDK wrapper with caching
  - `webhook_processor.rb` — SNS message parser (supports both `eventType` and legacy `notificationType` formats), returns a `Result` struct
  - `stats_aggregator.rb` — Dashboard statistics with database-agnostic date grouping (SQLite/PostgreSQL/MySQL)
  - `paginatable.rb` — Lightweight pagination (no external gem)
  - `auth/` — Pluggable authentication adapters (`:none`, `:devise`, `:cloudflare`, or custom)

- **`app/`** — Rails engine application layer:
  - Models: `Project` (has token for webhook URL), `Email` (status state machine with unidirectional transitions), `EmailEvent`
  - Controllers: `DashboardController`, `ProjectsController`, `EmailsController`, `TestEmailsController`, `WebhooksController`
  - `WebhooksController` skips session auth — uses project token from URL instead
  - `WebhookEventPersistor` service separates persistence from parsing

### Key patterns

- **Isolated engine**: All constants, tables, and routes are namespaced under `SesDashboard`. Tables prefixed `ses_dashboard_*`.
- **Webhook flow**: `WebhooksController` receives SNS POST -> `WebhookProcessor` parses -> `WebhookEventPersistor` persists Email + EmailEvent records.
- **Email status state machine**: Transitions are unidirectional (e.g., `sent` -> `delivered` but never backward). Defined in `Email::TRANSITIONS`.
- **Configuration DSL**: `SesDashboard.configure { |c| ... }` in host app initializer. Reset between tests via `SesDashboard.reset_configuration!`.

### Test setup

- File-based SQLite (`spec/tmp/test.db`) — enables Capybara system specs where Puma runs in a separate thread.
- Schema loaded directly from migration files in `rails_helper.rb` (no `db/schema.rb`).
- `DatabaseCleaner`: transaction strategy for unit specs, truncation for system specs.
- AWS calls stubbed via `spec/support/aws_mocks.rb` (`stub_ses_client` helper).
- Dummy Rails app at `spec/dummy/` mounts the engine at root.

### Docker Compose services

- `localstack` — Local AWS (SES + SNS) on port 4566
- `chrome` — Selenium standalone Chromium for system specs (noVNC on port 7900)
- `app` — Runs specs with all services wired up

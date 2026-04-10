# SES Dashboard
[![codecov](https://codecov.io/gh/antodoms/ses_dashboard/graph/badge.svg?token=0SSO12E12W)](https://codecov.io/gh/antodoms/ses_dashboard)
[![Gem Version](https://badge.fury.io/rb/ses-dashboard.svg)](https://badge.fury.io/rb/ses-dashboard)

A mountable Rails engine that provides a real-time dashboard for Amazon SES, tracking email delivery, bounces, complaints, opens, and clicks via SNS webhooks.

```mermaid
graph TB
    subgraph Host["Host Rails App"]
        Routes["routes.rb<br/>mount SesDashboard::Engine"]
        Initializer["initializer<br/>SesDashboard.configure"]
    end

    subgraph Engine["SesDashboard Engine"]
        direction TB
        subgraph Controllers
            DC["DashboardController"]
            PC["ProjectsController"]
            EC["EmailsController"]
            WC["WebhooksController"]
            TC["TestEmailsController"]
        end

        subgraph Auth["Authentication Adapters"]
            None[":none"]
            Devise[":devise"]
            CF[":cloudflare"]
            Custom["Custom adapter"]
        end

        subgraph Core["Core Library (lib/)"]
            Client["Client<br/>AWS SES SDK wrapper"]
            WP["WebhookProcessor<br/>SNS message parser"]
            SA["StatsAggregator<br/>Dashboard statistics"]
            Pag["Paginatable"]
        end

        subgraph Models
            Project["Project<br/>name, token"]
            Email["Email<br/>status, opens, clicks"]
            Event["EmailEvent<br/>event_type, event_data"]
        end

        subgraph Services
            WEP["WebhookEventPersistor"]
        end
    end

    subgraph AWS["Amazon Web Services"]
        SES["SES API<br/>send quota, statistics,<br/>send email"]
        SNS["SNS Topic<br/>email event notifications"]
    end

    Routes --> Controllers
    Initializer --> Auth
    DC --> SA
    EC --> Pag
    TC --> Client
    WC -->|"POST /webhook/:token"| WP
    WP --> WEP
    WEP --> Models
    Client --> SES
    SNS -->|"HTTP POST"| WC
    SA --> Models
    Project -->|has_many| Email
    Email -->|has_many| Event

    style Engine fill:#f0f4ff,stroke:#3366cc
    style AWS fill:#fff3e0,stroke:#ff9800
    style Host fill:#e8f5e9,stroke:#4caf50
```

## Features

- **Real-time webhook processing** -- receives SNS notifications for delivery, bounce, complaint, open, click, reject, and rendering failure events
- **Per-project dashboards** -- stat cards, email volume charts (Chart.js), and paginated activity logs
- **Pluggable authentication** -- ships with Devise, Cloudflare Zero Trust, and no-auth adapters; bring your own with any object that responds to `#authenticate(request)`
- **CSV/JSON export** -- export filtered email activity from any project
- **Test email sending** -- send test emails directly from the dashboard via the SES API
- **Status state machine** -- unidirectional email status transitions (sent -> delivered/bounced/etc.)
- **Database agnostic** -- works with SQLite, PostgreSQL, and MySQL
- **Lightweight pagination** -- no external pagination gem required

## Installation

Add the gem to your Gemfile:

```ruby
gem "ses_dashboard"
```

Then run:

```bash
bundle install
rails ses_dashboard:install:migrations
rails db:migrate
```

## Mounting

Mount the engine in your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount SesDashboard::Engine, at: "/ses-dashboard"
end
```

The dashboard is now available at `/ses-dashboard`.

## Configuration

Create an initializer at `config/initializers/ses_dashboard.rb`:

```ruby
SesDashboard.configure do |c|
  # AWS credentials (optional — the SDK credential chain is used by default:
  # SSO, IAM roles, instance profiles, environment variables, etc.)
  c.aws_region            = "us-east-1"
  c.aws_access_key_id     = ENV["AWS_ACCESS_KEY_ID"]
  c.aws_secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
  c.endpoint              = nil  # set to "http://localhost:4566" for LocalStack

  # Authentication adapter — :none, :devise, :cloudflare, or a custom object
  c.authentication_adapter = :devise

  # Cloudflare Zero Trust (only needed when using :cloudflare adapter)
  c.cloudflare_team_domain = "myteam.cloudflareaccess.com"
  c.cloudflare_aud         = "your-application-aud"

  # Dashboard behaviour
  c.per_page       = 25     # rows per page in the activity log
  c.time_zone      = "UTC"  # timezone for chart date grouping
  c.test_email_from = "noreply@example.com"

  # Caching & security
  c.cache_enabled        = true   # cache SES API responses in memory
  c.verify_sns_signature = true   # validate SNS signatures (enable in production)
end
```

## Authentication

Every controller action (except the webhook endpoint) runs through the configured authentication adapter.

| Adapter | Value | Notes |
|---|---|---|
| None | `:none` | Open access -- suitable for development |
| Devise | `:devise` | Calls `authenticate_user!` via Warden |
| Cloudflare Zero Trust | `:cloudflare` | Validates `CF_Authorization` JWT against JWKS |
| Custom | any object | Must respond to `#authenticate(request)` returning truthy/falsy |

```ruby
# Example custom adapter
class ApiKeyAuth
  def authenticate(request)
    request.headers["X-Api-Key"] == Rails.application.credentials.dashboard_key
  end
end

SesDashboard.configure do |c|
  c.authentication_adapter = ApiKeyAuth.new
end
```

## SNS Webhook Setup

Each project gets a unique webhook URL displayed on its dashboard page:

```
https://yourapp.com/ses-dashboard/webhook/<project-token>
```

To connect it to SES:

1. In the **AWS SNS console**, create a topic (or use an existing one).
2. Add a **subscription** with protocol **HTTPS** and the webhook URL above. The engine auto-confirms the subscription.
3. In the **SES console**, configure a **Configuration Set** with an SNS destination pointing to that topic. Select the event types you want to track (Send, Delivery, Bounce, Complaint, Open, Click, Reject, Rendering Failure).

The webhook endpoint authenticates via the project token in the URL and does not require a session.

## Database Schema

The engine creates three tables (prefixed `ses_dashboard_`):

| Table | Key Columns |
|---|---|
| `ses_dashboard_projects` | `name`, `token` (unique, auto-generated), `description` |
| `ses_dashboard_emails` | `project_id`, `message_id` (unique), `source`, `destination` (JSON), `subject`, `status`, `opens`, `clicks`, `sent_at` |
| `ses_dashboard_email_events` | `email_id`, `event_type`, `event_data` (JSON), `occurred_at` |

Email statuses: `sent`, `delivered`, `bounced`, `complained`, `rejected`, `failed`.

## Development

### Prerequisites

- Docker & Docker Compose (for system specs and local AWS)
- Ruby >= 3.0

### Setup

```bash
git clone <repo-url>
cd ses-dashboard
docker compose run --rm web bundle install
```

### Running Tests

```bash
# All tests (unit + controller + system) inside Docker
docker compose run --rm web bundle exec rspec

# Unit and controller tests only (no Docker needed)
bundle exec rspec spec/models spec/controllers spec/ses_dashboard

# Single test file
bundle exec rspec spec/models/ses_dashboard/email_spec.rb

# Single example by line number
bundle exec rspec spec/models/ses_dashboard/email_spec.rb:15
```

### Docker Compose Services

| Service | Purpose | Ports |
|---|---|---|
| `localstack` | Local AWS (SES + SNS) | 4566 |
| `chrome` | Selenium standalone Chromium | 4444 (WebDriver), 7900 (noVNC -- watch tests live) |
| `web` | Runs the test suite | 4001 (Puma) |

### Watching System Tests

Open http://localhost:7900 in your browser (no password) to watch Chrome execute system specs in real time via noVNC.

## License

MIT

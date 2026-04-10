# SES Dashboard

`ses_dashboard` is a reusable Ruby gem for exposing AWS SES dashboard data with pluggable authentication adapters.

## Setup

Install dependencies:

```bash
gem install bundler
bundle install
```

Run the test suite:

```bash
bundle exec rspec
```

## Features

- SES data wrapper for send quota, send statistics, and identity status
- Pluggable authentication adapter interface
- Optional Devise adapter for Rails hosts
- Local test mode with AWS SDK stubbing

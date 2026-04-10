require "capybara/rails"
require "selenium-webdriver"

# ---------------------------------------------------------------------------
# Server binding
#
# When SELENIUM_REMOTE_URL is set we're running inside Docker alongside a
# remote Chrome container.  Rather than relying on hostname resolution (which
# is fragile with `docker compose run`) we resolve the *container's own IP*
# on the Docker bridge network and hand that IP to Chrome.  This avoids DNS
# issues, HSTS preload problems (the .app gTLD is on Chrome's HSTS list),
# and the need for extra_hosts or --service-ports.
#
# Puma binds to 0.0.0.0 so it accepts connections from Chrome on the bridge
# network.
#
# Run system specs via Docker:
#   docker compose run --rm web bundle exec rspec spec/system
# ---------------------------------------------------------------------------
server_port = ENV.fetch("CAPYBARA_SERVER_PORT", "4001").to_i

server_host = ENV.fetch("CAPYBARA_SERVER_HOST") {
  if ENV["SELENIUM_REMOTE_URL"]
    # Docker: resolve this container's IP so Chrome can reach Puma directly.
    require "socket"
    IPSocket.getaddress(Socket.gethostname)
  else
    "127.0.0.1"
  end
}

Capybara.server         = :puma, { Silent: false }
Capybara.server_host    = "0.0.0.0"                              # accept connections from Chrome
Capybara.server_port    = server_port
Capybara.app_host       = "http://#{server_host}:#{server_port}"    # URL Chrome navigates to
Capybara.run_server = true
Capybara.always_include_port = true

# ---------------------------------------------------------------------------
# Remote Chrome driver — always uses the Selenium Grid / standalone container.
# The driver is registered lazily; SELENIUM_REMOTE_URL is only required when
# a system spec actually instantiates the driver.
# ---------------------------------------------------------------------------
Capybara.register_driver :remote_chrome do |app|
  url = ENV["SELENIUM_REMOTE_URL"] || begin
    raise <<~MSG
      SELENIUM_REMOTE_URL is not set — cannot connect to Chrome.

      Run system specs via Docker Compose so all services are available:
        docker compose run --rm web bundle exec rspec spec/system

      Or, if you have a Selenium Grid running locally:
        SELENIUM_REMOTE_URL=http://localhost:4444/wd/hub bundle exec rspec spec/system
    MSG
  end

  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--ignore-certificate-errors')
  options.add_argument('--ignore-ssl-errors')
  options.add_argument('--allow-insecure-localhost')
  options.add_argument("--allow-running-insecure-content")

  options.accept_insecure_certs = true

  Capybara::Selenium::Driver.new(app, browser: :remote, url: url, options: options)
end

Capybara.default_driver    = :remote_chrome
Capybara.javascript_driver = :remote_chrome

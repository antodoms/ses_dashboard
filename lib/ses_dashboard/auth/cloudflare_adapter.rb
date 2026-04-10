require "net/http"
require "uri"
require "base64"
require "openssl"
require "json"

module SesDashboard
  module Auth
    # Validates Cloudflare Zero Trust JWT tokens.
    #
    # Configure in your initializer:
    #   SesDashboard.configure do |c|
    #     c.authentication_adapter  = :cloudflare
    #     c.cloudflare_team_domain  = "myteam.cloudflareaccess.com"
    #     c.cloudflare_aud          = "your-application-audience-tag"
    #   end
    #
    class CloudflareAdapter < Base
      JWKS_CACHE_TTL = 600 # seconds

      def authenticate(request = nil)
        return false unless request
        token = extract_token(request)
        return false unless token

        payload = validate_jwt(token)
        return false unless payload

        config = SesDashboard.configuration
        return false if config.cloudflare_aud && payload["aud"] != [config.cloudflare_aud]

        true
      rescue => e
        log_error("Cloudflare JWT validation failed: #{e.message}")
        false
      end

      private

      def extract_token(request)
        # Cloudflare sets this cookie and/or header
        request.cookies["CF_Authorization"] ||
          request.get_header("HTTP_CF_ACCESS_JWT_ASSERTION")
      end

      def validate_jwt(token)
        header_b64, payload_b64, signature_b64 = token.split(".")
        return nil unless header_b64 && payload_b64 && signature_b64

        header  = JSON.parse(Base64.urlsafe_decode64(pad(header_b64)))
        payload = JSON.parse(Base64.urlsafe_decode64(pad(payload_b64)))

        return nil if payload["exp"].to_i < Time.now.to_i  # expired

        kid = header["kid"]
        key = fetch_public_key(kid)
        return nil unless key

        signing_input = "#{header_b64}.#{payload_b64}"
        signature     = Base64.urlsafe_decode64(pad(signature_b64))

        verified = key.verify(OpenSSL::Digest::SHA256.new, signature, signing_input)
        verified ? payload : nil
      end

      def fetch_public_key(kid)
        jwks = cached_jwks
        jwk  = jwks["keys"]&.find { |k| k["kid"] == kid }
        return nil unless jwk

        # Build RSA public key from JWK n/e parameters
        rsa = OpenSSL::PKey::RSA.new
        n   = OpenSSL::BN.new(Base64.urlsafe_decode64(pad(jwk["n"])), 2)
        e   = OpenSSL::BN.new(Base64.urlsafe_decode64(pad(jwk["e"])), 2)
        rsa.set_key(n, e, nil)
        rsa
      rescue
        nil
      end

      def cached_jwks
        @jwks_fetched_at ||= 0
        if Time.now.to_i - @jwks_fetched_at > JWKS_CACHE_TTL || @jwks_cache.nil?
          @jwks_cache      = fetch_jwks
          @jwks_fetched_at = Time.now.to_i
        end
        @jwks_cache
      end

      def fetch_jwks
        team_domain = SesDashboard.configuration.cloudflare_team_domain
        url = "https://#{team_domain}/cdn-cgi/access/certs"
        response = Net::HTTP.get(URI(url))
        JSON.parse(response)
      end

      def pad(str)
        str + "=" * ((4 - str.length % 4) % 4)
      end

      def log_error(msg)
        defined?(Rails) ? Rails.logger.warn("[SesDashboard] #{msg}") : nil
      end
    end
  end
end

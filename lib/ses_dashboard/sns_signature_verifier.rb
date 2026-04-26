require "net/http"
require "uri"
require "openssl"
require "base64"

module SesDashboard
  # Verifies the authenticity of an SNS HTTP POST using AWS's RSA signature.
  #
  # SNS signs messages with SHA1 (SignatureVersion "1") or SHA256
  # (SignatureVersion "2") using a per-region X.509 certificate hosted at
  # a amazonaws.com URL included in every message.
  #
  # Verification steps:
  #   1. Validate the SigningCertURL is from amazonaws.com (prevents substitution attacks)
  #   2. Fetch and parse the X.509 certificate
  #   3. Reconstruct the canonical string-to-sign
  #   4. Verify the Signature against the cert's public key
  #
  class SnsSignatureVerifier
    # Only trust certs hosted on Amazon's own infrastructure.
    CERT_URL_PATTERN = %r{\Ahttps://sns\.[a-z0-9\-]+\.amazonaws\.com/}.freeze

    class VerificationError < SesDashboard::Error; end

    def initialize(sns_message)
      @msg = sns_message
    end

    # Returns true if valid, raises VerificationError if not.
    def verify!
      validate_cert_url!
      cert   = fetch_cert
      digest = signature_version == "2" ? OpenSSL::Digest::SHA256.new : OpenSSL::Digest::SHA1.new

      unless cert.public_key.verify(digest, decoded_signature, string_to_sign)
        raise VerificationError, "SNS signature verification failed"
      end

      true
    end

    private

    def signature_version
      @msg["SignatureVersion"] || "1"
    end

    def validate_cert_url!
      url = @msg["SigningCertURL"].to_s
      unless url.match?(CERT_URL_PATTERN)
        raise VerificationError, "Invalid SigningCertURL: #{url.inspect}"
      end
    end

    def fetch_cert
      url  = URI(@msg["SigningCertURL"])
      pem  = Net::HTTP.get(url)
      OpenSSL::X509::Certificate.new(pem)
    rescue => e
      raise VerificationError, "Failed to fetch signing certificate: #{e.message}"
    end

    def decoded_signature
      Base64.decode64(@msg["Signature"].to_s)
    end

    # AWS canonical string-to-sign — field order is fixed per message type.
    # https://docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html
    def string_to_sign
      fields = case @msg["Type"]
               when "Notification"
                 notification_fields
               when "SubscriptionConfirmation", "UnsubscribeConfirmation"
                 subscription_fields
               else
                 raise VerificationError, "Unknown SNS message type: #{@msg["Type"].inspect}"
               end

      fields.map { |key| "#{key}\n#{@msg[key]}\n" }.join
    end

    def notification_fields
      fields = %w[Message MessageId Subject Timestamp TopicArn Type]
      # Subject is optional — omit if absent (AWS does the same)
      @msg["Subject"] ? fields : fields - ["Subject"]
    end

    def subscription_fields
      %w[Message MessageId SubscribeURL Timestamp Token TopicArn Type]
    end
  end
end

require "spec_helper"

RSpec.describe SesDashboard::SnsSignatureVerifier do
  # Generates a real RSA key pair and a self-signed X.509 cert for testing.
  def generate_cert_and_key
    key  = OpenSSL::PKey::RSA.generate(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version   = 2
    cert.serial    = 1
    cert.subject   = OpenSSL::X509::Name.parse("/CN=test")
    cert.issuer    = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after  = Time.now + 3600
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    [cert, key]
  end

  def build_notification(cert, key, overrides = {})
    msg = {
      "Type"             => "Notification",
      "MessageId"        => "msg-id-123",
      "TopicArn"         => "arn:aws:sns:ap-southeast-2:123456789:test-topic",
      "Message"          => "Hello",
      "Timestamp"        => "2024-01-15T10:00:00.000Z",
      "SignatureVersion" => "2",
      "SigningCertURL"   => "https://sns.ap-southeast-2.amazonaws.com/cert.pem"
    }.merge(overrides)

    # Build the canonical string-to-sign (Subject omitted as it's absent)
    string_to_sign = %w[Message MessageId Timestamp TopicArn Type]
      .map { |k| "#{k}\n#{msg[k]}\n" }.join

    digest    = OpenSSL::Digest::SHA256.new
    signature = Base64.strict_encode64(key.sign(digest, string_to_sign))

    msg.merge("Signature" => signature, "_cert" => cert)
  end

  let(:cert_and_key) { generate_cert_and_key }
  let(:cert) { cert_and_key[0] }
  let(:key)  { cert_and_key[1] }

  let(:notification) { build_notification(cert, key) }

  before do
    # Stub the HTTP cert fetch to return our self-signed cert
    allow(Net::HTTP).to receive(:get).with(URI(notification["SigningCertURL"])).and_return(cert.to_pem)
  end

  describe "#verify!" do
    it "returns true for a valid signature" do
      verifier = described_class.new(notification.reject { |k, _| k == "_cert" })
      expect(verifier.verify!).to be true
    end

    it "raises VerificationError when the signature is tampered" do
      tampered = notification.merge("Message" => "Tampered!", "_cert" => nil)
      verifier = described_class.new(tampered.reject { |k, _| k == "_cert" })
      expect { verifier.verify! }.to raise_error(SesDashboard::SnsSignatureVerifier::VerificationError, /failed/)
    end

    it "raises VerificationError for an invalid SigningCertURL" do
      bad_url = notification.merge("SigningCertURL" => "https://evil.com/cert.pem")
      verifier = described_class.new(bad_url.reject { |k, _| k == "_cert" })
      expect { verifier.verify! }.to raise_error(SesDashboard::SnsSignatureVerifier::VerificationError, /SigningCertURL/)
    end

    it "raises VerificationError when cert fetch fails" do
      allow(Net::HTTP).to receive(:get).and_raise(SocketError, "connection refused")
      verifier = described_class.new(notification.reject { |k, _| k == "_cert" })
      expect { verifier.verify! }.to raise_error(SesDashboard::SnsSignatureVerifier::VerificationError, /certificate/)
    end

    context "SubscriptionConfirmation" do
      it "verifies using the subscription field set" do
        msg = {
          "Type"             => "SubscriptionConfirmation",
          "MessageId"        => "sub-msg-id",
          "TopicArn"         => "arn:aws:sns:ap-southeast-2:123456789:test-topic",
          "Message"          => "confirm",
          "SubscribeURL"     => "https://sns.ap-southeast-2.amazonaws.com/confirm",
          "Token"            => "abc123token",
          "Timestamp"        => "2024-01-15T10:00:00.000Z",
          "SignatureVersion" => "2",
          "SigningCertURL"   => "https://sns.ap-southeast-2.amazonaws.com/cert.pem"
        }

        string_to_sign = %w[Message MessageId SubscribeURL Timestamp Token TopicArn Type]
          .map { |k| "#{k}\n#{msg[k]}\n" }.join
        signature = Base64.strict_encode64(key.sign(OpenSSL::Digest::SHA256.new, string_to_sign))
        msg["Signature"] = signature

        allow(Net::HTTP).to receive(:get).with(URI(msg["SigningCertURL"])).and_return(cert.to_pem)

        expect(described_class.new(msg).verify!).to be true
      end
    end

    context "SignatureVersion 1 (SHA1)" do
      it "verifies using SHA1 digest" do
        msg = build_notification(cert, key, "SignatureVersion" => "1").tap do |m|
          # Re-sign with SHA1
          string_to_sign = %w[Message MessageId Timestamp TopicArn Type]
            .map { |k| "#{k}\n#{m[k]}\n" }.join
          m["Signature"] = Base64.strict_encode64(key.sign(OpenSSL::Digest::SHA1.new, string_to_sign))
        end

        allow(Net::HTTP).to receive(:get).with(URI(msg["SigningCertURL"])).and_return(cert.to_pem)
        expect(described_class.new(msg.reject { |k, _| k == "_cert" }).verify!).to be true
      end
    end

    it "raises VerificationError for unknown message type" do
      msg = notification.merge("Type" => "UnsubscribeConfirmation")
      # UnsubscribeConfirmation uses the subscription field set, should not raise on type
      # but if we pass a completely unknown type it should raise
      msg = notification.merge("Type" => "WeirdType")
      verifier = described_class.new(msg.reject { |k, _| k == "_cert" })
      expect { verifier.verify! }.to raise_error(SesDashboard::SnsSignatureVerifier::VerificationError, /Unknown SNS message type/)
    end
  end
end

module SesDashboard
  # Evaluates a single forwarding rule against a WebhookProcessor::Result.
  #
  # A rule is a Hash with three keys:
  #   "field"    — which Result attribute to test
  #   "operator" — how to compare
  #   "value"    — what to compare against
  #
  # Supported fields:
  #   "event_type"  — string  ("bounce", "delivery", "complaint", …)
  #   "source"      — string  (From: address)
  #   "destination" — array   (To: addresses — rule passes if ANY element matches)
  #   "subject"     — string  (email subject)
  #
  # Supported operators:
  #   "in"          — field value is included in the given array
  #   "not_in"      — field value is NOT included in the given array
  #   "eq"          — exact string equality
  #   "not_eq"      — string inequality
  #   "starts_with" — prefix match (for arrays: any element matches)
  #   "ends_with"   — suffix match (for arrays: any element matches)
  #   "contains"    — substring match (for arrays: any element matches)
  #
  # New fields/operators can be added by extending the private methods below.
  #
  class ForwardRule
    def initialize(rule_hash)
      @field    = (rule_hash["field"]    || rule_hash[:field]).to_s
      @operator = (rule_hash["operator"] || rule_hash[:operator]).to_s
      @value    = rule_hash["value"]     || rule_hash[:value]
    end

    def match?(result)
      field_value = extract_field(result)
      evaluate(field_value)
    end

    private

    def extract_field(result)
      case @field
      when "event_type"  then result.event_type
      when "source"      then result.source
      when "destination" then result.destination
      when "subject"     then result.subject
      end
    end

    def evaluate(field_value)
      case @operator
      when "in"          then Array(@value).include?(field_value)
      when "not_in"      then !Array(@value).include?(field_value)
      when "eq"          then any_string_match(field_value) { |v| v == @value.to_s }
      when "not_eq"      then !any_string_match(field_value) { |v| v == @value.to_s }
      when "starts_with" then any_string_match(field_value) { |v| v.start_with?(@value.to_s) }
      when "ends_with"   then any_string_match(field_value) { |v| v.end_with?(@value.to_s) }
      when "contains"    then any_string_match(field_value) { |v| v.include?(@value.to_s) }
      else false
      end
    end

    # For array fields (e.g. destination), passes if ANY element matches.
    # For scalar fields, tests the single value.
    def any_string_match(field_value, &block)
      if field_value.is_a?(Array)
        field_value.any? { |v| block.call(v.to_s) }
      else
        block.call(field_value.to_s)
      end
    end
  end
end

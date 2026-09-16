# frozen_string_literal: true

require_relative 'test_helper'

class RedactTest < Buzzsprout::Test
  def test_redacts_authorization_header_values
    text = Buzzsprout::Redact.string('Authorization: Token token=super-secret-token')
    assert_includes text, 'Token token=[REDACTED]'
    refute_includes text, 'super-secret-token'
  end

  def test_redacts_api_token_query_and_json
    query = Buzzsprout::Redact.string('https://example.com/api?api_token=super-secret-token&date=2026-09-01')
    assert_includes query, 'api_token=[REDACTED]'
    refute_includes query, 'super-secret-token'

    json = Buzzsprout::Redact.string('{"api_token":"super-secret-token","id":10}')
    assert_includes json, '"api_token": "[REDACTED]"'
    refute_includes json, 'super-secret-token'
  end

  def test_redacts_known_long_secret_anywhere
    text = Buzzsprout::Redact.string('leaked super-secret-token in an error', known: 'super-secret-token')
    refute_includes text, 'super-secret-token'
    assert_includes text, '[REDACTED]'
  end

  def test_does_not_blindly_replace_short_secrets
    text = Buzzsprout::Redact.string('{"ok":true}', known: 'ok')
    assert_includes text, '"ok":true'
  end
end

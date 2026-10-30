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

  def test_redacts_authorization_code_without_touching_pkce_challenge
    url = 'https://example.com/oauth/callback?code=secret-auth-code&code_challenge=pkce-challenge&code_challenge_method=S256'
    text = Buzzsprout::Redact.uri(url)
    assert_includes text, 'code=[REDACTED]'
    refute_includes text, 'secret-auth-code'
    assert_includes text, 'code_challenge=pkce-challenge'
  end

  def test_does_not_redact_keys_merely_ending_in_a_secret_name
    text = Buzzsprout::Redact.string('https://example.com/api?barcode=12345&episode_code=abc')
    assert_includes text, 'barcode=12345'
    assert_includes text, 'episode_code=abc'
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

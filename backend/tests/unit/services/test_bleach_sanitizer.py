"""Unit tests for BleachSanitizer."""
from __future__ import annotations

import pytest

from app.services.sanitization.bleach_sanitizer import BleachSanitizer


@pytest.fixture
def sanitizer():
    return BleachSanitizer()


class TestSanitize:
    def test_strips_all_html_tags(self, sanitizer):
        assert sanitizer.sanitize("<b>hello</b>") == "hello"

    def test_strips_script_tags(self, sanitizer):
        result = sanitizer.sanitize("<script>alert(1)</script>")
        assert "<script>" not in result
        assert "alert(1)" in result  # text content kept, tag stripped

    def test_strips_nested_tags(self, sanitizer):
        result = sanitizer.sanitize("<div><p>text</p></div>")
        assert result.strip() == "text"

    def test_plain_text_unchanged(self, sanitizer):
        assert sanitizer.sanitize("hello world") == "hello world"

    def test_empty_string(self, sanitizer):
        assert sanitizer.sanitize("") == ""

    def test_xss_attribute_injection(self, sanitizer):
        result = sanitizer.sanitize('<a href="javascript:alert(1)">click</a>')
        assert "javascript:" not in result

    def test_strips_iframe(self, sanitizer):
        result = sanitizer.sanitize('<iframe src="evil.com"></iframe>')
        assert "<iframe>" not in result
        assert "iframe" not in result


class TestSanitizeMarkdown:
    def test_allows_bold(self, sanitizer):
        assert sanitizer.sanitize_markdown("<b>bold</b>") == "<b>bold</b>"

    def test_allows_code(self, sanitizer):
        assert sanitizer.sanitize_markdown("<code>x = 1</code>") == "<code>x = 1</code>"

    def test_strips_script_tag(self, sanitizer):
        result = sanitizer.sanitize_markdown("<script>evil()</script>")
        assert "<script>" not in result

    def test_strips_dangerous_href(self, sanitizer):
        result = sanitizer.sanitize_markdown('<a href="javascript:alert(1)">link</a>')
        assert "javascript:" not in result

    def test_allows_safe_link(self, sanitizer):
        result = sanitizer.sanitize_markdown('<a href="https://example.com">link</a>')
        assert 'href="https://example.com"' in result

    def test_allows_heading_tags(self, sanitizer):
        assert sanitizer.sanitize_markdown("<h1>Title</h1>") == "<h1>Title</h1>"

    def test_strips_iframe_in_markdown(self, sanitizer):
        result = sanitizer.sanitize_markdown('<iframe src="evil.com"></iframe>')
        assert "<iframe>" not in result

    def test_allows_blockquote(self, sanitizer):
        assert sanitizer.sanitize_markdown("<blockquote>quote</blockquote>") == "<blockquote>quote</blockquote>"

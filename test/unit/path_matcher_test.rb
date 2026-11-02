require_relative "../test_helper"

class RubylodeUptimeKuma::PathMatcherTest < ActiveSupport::TestCase
  def matcher(*patterns)
    RubylodeUptimeKuma::PathMatcher.new(patterns)
  end

  test "a plain pattern matches exactly that page" do
    assert matcher("/issues").match?("/issues")
    refute matcher("/issues").match?("/issues/1")
    refute matcher("/issues").match?("/projects/a/issues")
  end

  test "a query string, a fragment and a trailing slash are ignored" do
    assert matcher("/issues").match?("/issues?set_filter=1&status_id=o")
    assert matcher("/issues").match?("/issues/")
    assert matcher("/issues/").match?("/issues")
    assert matcher("/issues").match?("/issues#top")
  end

  test "the root path matches only the root" do
    assert matcher("/").match?("/")
    assert matcher("/").match?("/?foo=1")
    refute matcher("/").match?("/issues")
  end

  test "a star stands for anything inside one segment" do
    assert matcher("/projects/*/issues").match?("/projects/shop/issues")
    refute matcher("/projects/*/issues").match?("/projects/shop/sub/issues")
    refute matcher("/projects/*/issues").match?("/projects//issues/x")
    assert matcher("/issues/1*").match?("/issues/123")
  end

  test "a double star stands for anything including slashes" do
    assert matcher("/projects/shop/**").match?("/projects/shop/wiki/Start/history")
    assert matcher("/wiki/**").match?("/wiki/a")
  end

  test "regular expression characters in a pattern are taken literally" do
    assert matcher("/a.b").match?("/a.b")
    refute matcher("/a.b").match?("/axb")
    refute matcher("/a+").match?("/aaa")
  end

  test "any of several patterns may match, and none matches nothing" do
    assert matcher("/news", "/issues").match?("/issues")
    refute matcher.match?("/issues")
  end

  test "wildcards never reach sign-in, account, Administration or the settings" do
    broad = matcher("/**", "/*", "/*/*")

    %w[/login /logout /account /account/register /admin /admin/plugins /settings /settings/plugin/x].each do |path|
      refute broad.match?(path), path
    end
    assert broad.match?("/issues")
  end

  test "a protected page can be listed explicitly" do
    assert matcher("/settings").match?("/settings")
    assert matcher("/admin/*").match?("/admin/plugins")
    refute matcher("/admin/*").match?("/settings")
  end

  test "a pattern that is not a path is ignored" do
    refute matcher("issues").match?("issues")
    refute matcher("https://example.com/issues").match?("/issues")
    refute matcher("//example.com/issues").match?("//example.com/issues")
  end

  test "problems with a pattern are named" do
    assert_nil RubylodeUptimeKuma::PathMatcher.problem_with("/issues")
    assert_equal :must_start_with_slash, RubylodeUptimeKuma::PathMatcher.problem_with("issues")
    assert_equal :must_start_with_slash, RubylodeUptimeKuma::PathMatcher.problem_with("https://example.com/")
    assert_equal :no_host, RubylodeUptimeKuma::PathMatcher.problem_with("//example.com")
    assert_equal :too_long, RubylodeUptimeKuma::PathMatcher.problem_with("/#{'a' * 200}")
    assert_equal :bad_characters, RubylodeUptimeKuma::PathMatcher.problem_with("/is sues")
    assert_equal :bad_characters, RubylodeUptimeKuma::PathMatcher.problem_with("/a<b>")
  end

  test "patterns are read one per line with blanks and comments skipped" do
    assert_equal ["/issues", "/news"], RubylodeUptimeKuma::PathMatcher.patterns_from("# where\n/issues\n\n  /news  \n")
  end
end

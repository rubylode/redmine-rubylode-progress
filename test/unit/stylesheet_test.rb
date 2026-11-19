# Rubylode Progress: a progress page for Redmine projects
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path("../test_helper", __dir__)

class StylesheetTest < ActiveSupport::TestCase
  PLUGIN_ROOT = File.expand_path("../..", __dir__)
  STYLESHEET = File.read(File.join(PLUGIN_ROOT, "assets/stylesheets/rubylode_progress.css"))
  THEMING = File.read(File.join(PLUGIN_ROOT, "docs/theming.md"))
  TOKEN_BLOCK_PATTERN = /:where\(:root\)\s*\{(.*?)\}/m
  PROPERTY_PATTERN = /(--rubylode-progress-[a-z-]+)\s*:\s*([^;]+);/
  STATUSES = %w[done next needs-you waiting to-do].freeze

  def comment_free_stylesheet
    STYLESHEET.gsub(%r{/\*.*?\*/}m, "")
  end

  def light_tokens
    comment_free_stylesheet[TOKEN_BLOCK_PATTERN, 1].scan(PROPERTY_PATTERN).to_h { |name, value| [name, value.strip] }
  end

  def dark_tokens
    block = THEMING[/```css\n(.*?)```/m, 1]
    block.scan(PROPERTY_PATTERN).to_h { |name, value| [name, value.strip] }
  end

  def colour_tokens
    light_tokens.select { |_name, value| value.start_with?("#") }
  end

  def channel_luminance(channel)
    scaled = channel / 255.0
    scaled <= 0.03928 ? scaled / 12.92 : ((scaled + 0.055) / 1.055)**2.4
  end

  def relative_luminance(hex)
    red, green, blue = hex.delete("#").scan(/../).map { |pair| pair.to_i(16) }
    (0.2126 * channel_luminance(red)) + (0.7152 * channel_luminance(green)) + (0.0722 * channel_luminance(blue))
  end

  def contrast_ratio(first_hex, second_hex)
    lighter, darker = [relative_luminance(first_hex), relative_luminance(second_hex)].sort.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  def assert_readable(tokens, label)
    pairs = [%w[text-color surface], %w[muted-text-color surface], %w[surface accent-color]]
    pairs += STATUSES.map { |status| ["#{status}-color", "#{status}-background"] }
    pairs.each do |foreground, background|
      foreground_hex = tokens.fetch("--rubylode-progress-#{foreground}")
      background_hex = tokens.fetch("--rubylode-progress-#{background}")
      ratio = contrast_ratio(foreground_hex, background_hex)
      assert_operator ratio, :>=, 4.5, "#{label}: #{foreground} on #{background} is #{ratio.round(2)}:1"
    end
  end

  def rules
    comment_free_stylesheet.gsub(TOKEN_BLOCK_PATTERN, "").scan(/([^{}]+)\{([^{}]*)\}/m)
  end

  test "every colour is a custom property" do
    outside_token_block = comment_free_stylesheet.gsub(TOKEN_BLOCK_PATTERN, "")

    assert_empty outside_token_block.scan(/#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(/)
    assert_operator colour_tokens.size, :>=, 16
  end

  test "the stylesheet has no prefers-color-scheme rule" do
    assert_no_match(/prefers-color-scheme/, STYLESHEET)
  end

  test "the dark block in docs/theming.md sets every colour token of the stylesheet" do
    assert_empty colour_tokens.keys - dark_tokens.keys
  end

  test "text and muted text reach 4.5:1 on the surface, and each status colour on its tint, in the light defaults" do
    assert_readable(light_tokens, "light")
  end

  test "text and muted text reach 4.5:1 on the surface, and each status colour on its tint, in the dark block" do
    assert_readable(dark_tokens, "dark")
  end

  test "no rule selects #content, body or a bare element" do
    selectors = rules.flat_map { |selector_text, _| selector_text.split(",").map(&:strip) }

    assert_not_empty selectors
    selectors.each do |selector|
      assert selector.start_with?(".rubylode-progress"), "#{selector.inspect} is not under .rubylode-progress"
      assert_no_match(/#content|\bbody\b/, selector)
    end
  end

  test "phone width puts the tiles two by two and stacks the panel" do
    phone_block = comment_free_stylesheet[/@media \(max-width: 640px\)\s*\{(.*)\}\s*\z/m, 1]

    assert_match(/\.rubylode-progress-tiles\s*\{[^}]*repeat\(2, 1fr\)/, phone_block)
    assert_match(/\.rubylode-progress-tracker__bar\s*\{[^}]*flex-direction: column/, phone_block)
  end

  test "a focus-visible rule covers links, the filters and summary" do
    selectors = rules.select { |_selector, body| body.include?("outline") }.map(&:first).join(",")

    assert_match(/a:focus-visible/, selectors)
    assert_match(/\.rubylode-progress-filter:focus-visible/, selectors)
    assert_match(/summary:focus-visible/, selectors)
    assert_match(/--rubylode-progress-focus-color/, rules.map(&:last).join)
  end

  test "every --rubylode-progress- property in the stylesheet is listed in docs/theming.md" do
    used = comment_free_stylesheet.scan(/--rubylode-progress-[a-z-]+/).uniq

    assert_empty(used.reject { |name| THEMING.include?("`#{name}`") })
  end
end

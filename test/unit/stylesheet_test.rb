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
    pairs = [%w[text-color surface], %w[muted-text-color surface], %w[surface accent-color], %w[on-accent-color accent-color]]
    pairs += STATUSES.map { |status| ["#{status}-color", "#{status}-background"] }
    pairs << %w[behind-color behind-background]
    pairs.each do |foreground, background|
      foreground_hex = tokens.fetch("--rubylode-progress-#{foreground}")
      background_hex = tokens.fetch("--rubylode-progress-#{background}")
      ratio = contrast_ratio(foreground_hex, background_hex)
      assert_operator ratio, :>=, 4.5, "#{label}: #{foreground} on #{background} is #{ratio.round(2)}:1"
    end
  end

  # The marks and the filled line carry meaning, so they need 3:1 against the surface, in either block.
  def assert_marks_visible(tokens, label)
    %w[done-color behind-color accent-color muted-text-color next-color needs-you-color waiting-color].each do |name|
      ratio = contrast_ratio(tokens.fetch("--rubylode-progress-#{name}"), tokens.fetch("--rubylode-progress-surface"))
      assert_operator ratio, :>=, 3.0, "#{label}: #{name} on the surface is #{ratio.round(2)}:1"
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

  test "marks and the filled line reach 3:1 on the surface, in both blocks" do
    assert_marks_visible(light_tokens, "light")
    assert_marks_visible(dark_tokens, "dark")
  end

  test "the New issue button's text is the on-accent colour, and it beats a theme's link colour by specificity" do
    body = rules.find { |selector, _| selector.include?("new-issue-button:link") }&.last.to_s

    assert_match(/color: var\(--rubylode-progress-on-accent-color\)/, body)
    assert_match(/background: var\(--rubylode-progress-accent-color\)/, body)
    assert_equal "#ffffff", light_tokens.fetch("--rubylode-progress-on-accent-color")
  end

  test "the second pass classes are styled: marks per status, the fold toggle, the info button, the refused target" do
    selectors = rules.flat_map { |selector_text, _| selector_text.split(",").map(&:strip) }.join(" ")

    %w[.rubylode-progress-row__mark--next .rubylode-progress-row__mark--waiting .rubylode-progress-row__mark--needs-you
       .rubylode-progress-row__mark--in-progress .rubylode-progress-closed-fold__show .rubylode-progress-closed-fold__hide
       .rubylode-progress-rules__icon .rubylode-progress-drop-refused .rubylode-progress-stage__tag
       .rubylode-progress-tracker__updated .rubylode-progress-tracker__percent-note .rubylode-progress-track__heading].each do |name|
      assert_includes selectors, name
    end
    assert_match(/\.rubylode-progress-row__mark--waiting\s*\{[^}]*dashed/, comment_free_stylesheet)
    assert_match(/\.rubylode-progress-closed-fold\[open\] \.rubylode-progress-closed-fold__show\s*\{[^}]*display: none/, comment_free_stylesheet)
    assert_match(/\.rubylode-progress-rules__summary\s*\{[^}]*min-height: 28px/, comment_free_stylesheet)
    assert_match(/\.rubylode-progress-drop-refused\s*\{[^}]*--rubylode-progress-behind-color/, comment_free_stylesheet)
  end

  test "the status button is styled in theme properties only, with a caret, and is a 44px target on a touch screen" do
    selectors = rules.flat_map { |selector_text, _| selector_text.split(",").map(&:strip) }.join(" ")

    %w[.rubylode-progress-status-button .rubylode-progress-status-button::after .rubylode-progress-status-choice__meaning].each do |name|
      assert_includes selectors, name
    end
    body = rules.find { |selector, _| selector.strip == ".rubylode-progress-status-button" }&.last.to_s
    assert_match(/color: var\(--rubylode-progress-text-color\)/, body)
    assert_match(/border: 1px solid var\(--rubylode-progress-line-color\)/, body)
    touch_rule = rules.find { |selector, _| selector.include?("rubylode-progress-status-button") && selector.include?("rubylode-progress-filter") }&.last.to_s
    assert_match(/min-height: 44px/, touch_rule)
  end

  test "the issue numbers and assignees are set off by a thin line in the theme's line colour" do
    body = rules.find { |selector, _| selector.include?("step__assignee") && selector.include?("row__number") }&.last.to_s

    assert_match(/border-left: 1px solid var\(--rubylode-progress-line-color\)/, body)
  end

  test "the new theme properties have their light defaults" do
    assert_equal "#b3261e", light_tokens.fetch("--rubylode-progress-behind-color")
    assert_equal "#fdecea", light_tokens.fetch("--rubylode-progress-behind-background")
    assert_equal "#d5dbe2", light_tokens.fetch("--rubylode-progress-track-empty-color")
    assert_equal "4px", light_tokens.fetch("--rubylode-progress-rail-width")
    assert_equal "1.6em", light_tokens.fetch("--rubylode-progress-stage-mark-size")
    assert_equal "1.4em", light_tokens.fetch("--rubylode-progress-rail-mark-size")
    assert_equal "none", light_tokens.fetch("--rubylode-progress-column-width")
  end

  test "the layout classes of the design review are styled: marks, rail, tracker, pills, rows" do
    selectors = rules.flat_map { |selector_text, _| selector_text.split(",").map(&:strip) }.join(" ")

    %w[.rubylode-progress-stage-mark--done .rubylode-progress-stage-mark--partial .rubylode-progress-stage-mark--current
       .rubylode-progress-track__segment .rubylode-progress-stage-item::after .rubylode-progress-stage-item:first-child::before
       .rubylode-progress-notice--behind .rubylode-progress-notice--due-soon .rubylode-progress-filter--behind
       .rubylode-progress-filter--empty .rubylode-progress-group__button .rubylode-progress-rules .rubylode-progress-closed-fold
       .rubylode-progress-row__date--overdue .rubylode-progress-hover-actions .rubylode-progress-columns].each do |name|
      assert_includes selectors, name
    end
  end

  test "the rail line and the tracker segment are gradients of the inline share and colour properties" do
    gradients = rules.select { |selector, _| selector.include?("stage-item::after") || selector.include?("track__segment") }.map(&:last).join

    assert_match(/linear-gradient\(180deg, var\(--rubylode-progress-colour-below\) var\(--rubylode-progress-share-below\)/m, gradients)
    assert_match(/linear-gradient\(90deg, var\(--rubylode-progress-segment-color\) var\(--rubylode-progress-share\)/m, gradients)
  end

  test "the stage list and the checklist are a wrapping flex row with the sizes of the plan, and no sticky or 100vh" do
    assert_match(/\.rubylode-progress-columns\s*\{[^}]*flex-wrap: wrap/, comment_free_stylesheet)
    assert_match(/\.rubylode-progress-stage-list\s*\{[^}]*flex: 1 1 34em;[^}]*min-width: 0/, comment_free_stylesheet)
    assert_match(/\.rubylode-progress-checklist-column\s*\{[^}]*flex: 1 1 30em;[^}]*min-width: 0/, comment_free_stylesheet)
    assert_no_match(/position: sticky|100vh/, comment_free_stylesheet)
  end

  test "the pencil and the new-tab link show on hover and focus, always on touch screens" do
    assert_match(/\.rubylode-progress-row:focus-within \.rubylode-progress-hover-actions/, comment_free_stylesheet)
    assert_match(/@media \(hover: none\)\s*\{\s*\.rubylode-progress-hover-actions\s*\{\s*opacity: 1/, comment_free_stylesheet)
  end

  test "phone width stacks the columns, scrolls the pills sideways, swaps the group buttons for a select and sizes touch targets" do
    phone_block = comment_free_stylesheet[/@media \(max-width: 640px\)\s*\{(.*)\}\s*\z/m, 1]

    assert_match(/\.rubylode-progress-columns\s*\{[^}]*flex-direction: column/, phone_block)
    assert_match(/\.rubylode-progress-stage-list\s*\{[^}]*order: 2/, phone_block)
    assert_match(/\.rubylode-progress-filters\s*\{[^}]*overflow-x: auto/, phone_block)
    assert_match(/\.rubylode-progress-group__buttons\s*\{[^}]*display: none/, phone_block)
    assert_match(/\.rubylode-progress-group__select-form\s*\{[^}]*display: block/, phone_block)
    assert_match(/\.rubylode-progress-more__button\s*\{[^}]*min-height: 44px/, phone_block)
  end

  test "a focus-visible rule covers links, the filters and summary" do
    selectors = rules.select { |_selector, body| body.include?("outline") }.map(&:first).join(",")

    assert_match(/a:focus-visible/, selectors)
    assert_match(/\.rubylode-progress-filter:focus-visible/, selectors)
    assert_match(/summary:focus-visible/, selectors)
    assert_match(/--rubylode-progress-focus-color/, rules.map(&:last).join)
  end

  test "the drag and drop look: the drop-target property follows the accent, the dark block gives it a value, the classes are styled" do
    assert_equal "var(--rubylode-progress-accent-color)", light_tokens.fetch("--rubylode-progress-drop-target-color")
    assert_equal "#6cb2eb", dark_tokens.fetch("--rubylode-progress-drop-target-color")
    ratio = contrast_ratio(dark_tokens.fetch("--rubylode-progress-drop-target-color"), dark_tokens.fetch("--rubylode-progress-surface"))
    assert_operator ratio, :>=, 3.0
    selectors = rules.flat_map { |selector_text, _| selector_text.split(",").map(&:strip) }.join(" ")

    %w[.rubylode-progress-hint .rubylode-progress-dragged .rubylode-progress-drop-over .rubylode-progress-move-message].each do |name|
      assert_includes selectors, name
    end
    assert_match(/\.rubylode-progress-drop-over\s*\{[^}]*var\(--rubylode-progress-drop-target-color\)/, comment_free_stylesheet)
    assert_match(/\.rubylode-progress-row\[draggable="true"\]\s*\{[^}]*cursor: grab/, comment_free_stylesheet)
  end

test "a narrow checklist column puts a row's number, assignee, pill and date on a second line under the title" do
  css = comment_free_stylesheet

  assert_match(/\.rubylode-progress-checklist-column\s*\{[^}]*container-type: inline-size/, css)
  narrow = css[/@container \(max-width: [\d.]+em\)\s*\{(.*?)\n\}\n/m, 1]
  assert narrow, "the row layout needs a container query on the checklist column's width"
  assert_match(/\.rubylode-progress-row\s*\{[^}]*display: flex[^}]*flex-wrap: wrap/m, narrow)
  assert_match(/\.rubylode-progress-row__main\s*\{[^}]*flex: 1 1 calc\(100% - /m, narrow)
end

  # Redmine puts the menu item's name on its link as a class, so the top menu and the project menu carry
  # a.rubylode-progress. The page wrapper is a div with the same class and must not style those links.
  test "the page wrapper rule is scoped to the div, so the menu links named rubylode-progress are not laid out as the page" do
    css = comment_free_stylesheet

    assert_no_match(/^\.rubylode-progress\s*\{/, css)
    assert_match(/^\.rubylode-progress:not\(a\)\s*\{[^}]*display: flex/m, css)
  end

  test "every --rubylode-progress- property in the stylesheet is listed in docs/theming.md" do
    used = comment_free_stylesheet.scan(/--rubylode-progress-[a-z-]+/).uniq

    assert_empty(used.reject { |name| THEMING.include?("`#{name}`") })
  end

  # A wrapping column leaves the checklist as tall as the whole page on a phone, with a blank gap before the stage list.
  test "the two columns stack without wrapping on a phone" do
    phone_rules = comment_free_stylesheet[/@media \(max-width: 640px\) \{(.*)/m, 1]
    assert_match(/\.rubylode-progress-columns \{[^}]*flex-direction: column;[^}]*flex-wrap: nowrap;/m, phone_rules)
  end
end

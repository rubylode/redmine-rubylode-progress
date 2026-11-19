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

# Every translation key the views, helpers, controllers and models ask for exists in en.yml, so a page never shows
# "translation missing". A key built with #{...} is checked as far as its fixed part: that must be a section with entries.
class LocaleStructureTest < ActiveSupport::TestCase
  PLUGIN_ROOT = File.expand_path("../..", __dir__)
  ENGLISH = YAML.load_file(File.join(PLUGIN_ROOT, "config/locales/en.yml")).fetch("en")
  SOURCE_GLOBS = %w[app/**/*.{erb,rb} lib/**/*.rb init.rb].freeze
  KEY_PATTERN = /\b(?:l|t|translate|I18n\.t|I18n\.translate)\(\s*["']([a-z_][a-z0-9_.]*(?:\#\{[^}]*\}[a-z0-9_.]*)*)["']/

  def source_files
    SOURCE_GLOBS.flat_map { |pattern| Dir.glob(File.join(PLUGIN_ROOT, pattern)) }
  end

  # Only the plugin's own keys: Redmine ships the rest (date formats, button labels).
  def used_keys
    source_files.flat_map { |path| File.read(path).scan(KEY_PATTERN).flatten }.uniq.select do |key|
      key.start_with?("rubylode_progress.") || ENGLISH.key?(key)
    end
  end

  def node_for(path)
    path.split(".").reduce(ENGLISH) { |node, part| node.is_a?(Hash) ? node[part] : nil }
  end

  test "the views and helpers ask for translation keys at all" do
    assert_operator used_keys.size, :>, 40
  end

  test "every key used in the plugin exists in en.yml" do
    missing = used_keys.reject do |key|
      fixed_part = key.split("\#{").first.delete_suffix(".")
      node = node_for(fixed_part)
      key.include?("\#{") ? node.is_a?(Hash) && node.any? : !node.nil?
    end
    assert_empty missing, "keys used but not in en.yml"
  end

  test "the keys Redmine itself reads for the module, the permission and the menu exist" do
    %w[project_module_rubylode_progress permission_view_rubylode_progress label_rubylode_progress].each do |key|
      assert ENGLISH.key?(key), key
    end
  end

  test "no string holds an en dash, an em dash or an arrow" do
    strings = []
    collect = ->(node) { node.is_a?(Hash) ? node.each_value(&collect) : strings << node.to_s }
    collect.call(ENGLISH)
    strings.each { |string| refute_match(/[–—→]/, string) }
  end
end

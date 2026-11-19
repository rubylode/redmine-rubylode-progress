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

# The release workflow refuses a tag whose version has no CHANGELOG entry; this fails the suite earlier.
class ChangelogTest < ActiveSupport::TestCase
  PLUGIN_ROOT = File.expand_path("../..", __dir__)

  test "the version in init.rb has a CHANGELOG entry" do
    version = File.read(File.join(PLUGIN_ROOT, "init.rb"))[/^\s*version\s+["']([^"']+)["']/, 1]
    assert version, "no version in init.rb"
    assert_equal version, Redmine::Plugin.find(:redmine_rubylode_progress).version
    changelog = File.read(File.join(PLUGIN_ROOT, "CHANGELOG.md"))
    assert_match(/^##\s+\[?#{Regexp.escape(version)}\]?\s+-\s+\d{4}-\d{2}-\d{2}/, changelog)
  end
end

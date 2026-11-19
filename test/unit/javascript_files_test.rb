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

class JavascriptFilesTest < ActiveSupport::TestCase
  SCRIPTS = Dir[File.expand_path("../../assets/javascripts/*.js", __dir__)].freeze

  test "the plugin ships its scripts" do
    assert_not_empty SCRIPTS
  end

  # A script with a syntax error is not loaded at all, and the page then does nothing when it is used. A "\n" typed
  # into the source as two characters, where a line break belongs, did exactly that to the drag and drop script.
  test "no script holds a backslash-n where a line break belongs" do
    SCRIPTS.each do |path|
      File.foreach(path).with_index(1) do |line, number|
        next unless line.match?(/["'`]\\n\s*(const|let|var|import|export|class|function|async)\b/)

        flunk "#{File.basename(path)}:#{number} has a literal backslash-n between two statements"
      end
    end
  end
end

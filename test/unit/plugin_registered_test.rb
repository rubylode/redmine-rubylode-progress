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

class PluginRegisteredTest < ActiveSupport::TestCase
  test "the plugin is registered for Redmine 7.0 and newer" do
    plugin = Redmine::Plugin.find(:redmine_rubylode_progress)
    assert_equal "Rubylode Progress", plugin.name
    assert_equal "0.1.0", plugin.version

    project_module = Redmine::AccessControl.available_project_modules
    assert_includes project_module, :rubylode_progress

    permission = Redmine::AccessControl.permission(:view_rubylode_progress)
    assert_not_nil permission
    assert_equal :rubylode_progress, permission.project_module
    assert permission.read?, "View progress must be a read-only permission"
  end
end

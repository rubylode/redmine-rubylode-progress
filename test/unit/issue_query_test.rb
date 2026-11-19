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

class IssueQueryTest < ActiveSupport::TestCase
  test "the open filters ask for open issues in the project's versions" do
    parameters = RubylodeProgress::IssueQuery.parameters_for("open", version_ids: [3, 4])

    assert_equal 1, parameters[:set_filter]
    assert_equal %w[status_id fixed_version_id], parameters[:f]
    assert_equal "o", parameters[:op]["status_id"]
    assert_equal %w[3 4], parameters[:v]["fixed_version_id"]
  end

  test "Done asks for closed issues, All for any status" do
    assert_equal "c", RubylodeProgress::IssueQuery.parameters_for("done", version_ids: [1])[:op]["status_id"]
    assert_equal "*", RubylodeProgress::IssueQuery.parameters_for("all", version_ids: [1])[:op]["status_id"]
  end

  test "Needs you adds the assignee me, Overdue adds a due date before today" do
    needs_you = RubylodeProgress::IssueQuery.parameters_for("needs_you", version_ids: [1])
    assert_includes needs_you[:f], "assigned_to_id"
    assert_equal ["me"], needs_you[:v]["assigned_to_id"]

    overdue = RubylodeProgress::IssueQuery.parameters_for("overdue", version_ids: [1])
    assert_includes overdue[:f], "due_date"
    assert_equal "<t-", overdue[:op]["due_date"]
    assert_equal ["0"], overdue[:v]["due_date"]
  end

  test "Next up cannot be written as a Redmine filter, so it carries only the project's versions and open status" do
    parameters = RubylodeProgress::IssueQuery.parameters_for("next", version_ids: [1])

    assert_equal %w[status_id fixed_version_id], parameters[:f]
  end

  test "an unknown filter is treated as Open and ids are written as integers" do
    parameters = RubylodeProgress::IssueQuery.parameters_for("bogus; drop", version_ids: ["7", 8])

    assert_equal "o", parameters[:op]["status_id"]
    assert_equal %w[7 8], parameters[:v]["fixed_version_id"]
  end
end

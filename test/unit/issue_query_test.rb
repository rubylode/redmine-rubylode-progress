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
  test "the chosen assignee, tracker and category become Redmine filters, and none is its none operator" do
    parameters = RubylodeProgress::IssueQuery.parameters_for("open", version_ids: [1],
                                                                     narrowing: { "assignee" => "none", "tracker" => "2", "category" => "5" })

    assert_equal %w[status_id fixed_version_id assigned_to_id tracker_id category_id], parameters[:f]
    assert_equal ["!*", [""]], [parameters[:op]["assigned_to_id"], parameters[:v]["assigned_to_id"]]
    assert_equal ["=", ["2"]], [parameters[:op]["tracker_id"], parameters[:v]["tracker_id"]]
    assert_equal ["=", ["5"]], [parameters[:op]["category_id"], parameters[:v]["category_id"]]
  end

  test "any adds no filter, and Needs you keeps its own assignee rule" do
    any = { "assignee" => "any", "tracker" => "any", "category" => "any" }
    assert_equal %w[status_id fixed_version_id], RubylodeProgress::IssueQuery.parameters_for("open", version_ids: [1], narrowing: any)[:f]

    parameters = RubylodeProgress::IssueQuery.parameters_for("needs_you", version_ids: [1], narrowing: any.merge("assignee" => "9"))
    assert_equal ["me"], parameters[:v]["assigned_to_id"]
    assert_equal 1, parameters[:f].count("assigned_to_id")
  end

  test "a narrowing value that is not a number is refused" do
    assert_raises(ArgumentError) do
      RubylodeProgress::IssueQuery.parameters_for("open", version_ids: [1], narrowing: { "tracker" => "2; drop" })
    end
  end
end

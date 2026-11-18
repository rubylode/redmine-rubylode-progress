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


# Plain stand-ins for Redmine issues, so the item status rule and the Next limit are tested without a database.
module StatusDoubles
  StatusIssueDouble = Struct.new(:id, :status_id, :closed, :assigned_to_id, :blocked, :priority_position, :due_date,
                                 keyword_init: true) do
    def closed?
      closed
    end

    def blocked?
      blocked
    end
  end

  VIEWER_ID = 7
  VIEWER_GROUP_ID = 10
  OTHER_USER_ID = 8
  OPEN_STATUS_ID = 1
  IN_PROGRESS_STATUS_ID = 2
  WAITING_STATUS_ID = 3
  CLOSED_STATUS_ID = 5
  LOW_PRIORITY = 1
  NORMAL_PRIORITY = 2
  HIGH_PRIORITY = 3

  def issue(id, status_id: OPEN_STATUS_ID, closed: false, assigned_to_id: nil, blocked: false,
            priority_position: NORMAL_PRIORITY, due_date: nil)
    StatusIssueDouble.new(id: id, status_id: status_id, closed: closed, assigned_to_id: assigned_to_id,
                          blocked: blocked, priority_position: priority_position, due_date: due_date)
  end

  def status_rule(viewer_id: VIEWER_ID, viewer_group_ids: [VIEWER_GROUP_ID], in_progress_status_ids: [IN_PROGRESS_STATUS_ID],
                  waiting_status_ids: [WAITING_STATUS_ID], next_issue_ids: [])
    RubylodeProgress::ItemStatusRule.new(viewer_id: viewer_id, viewer_group_ids: viewer_group_ids,
                                         in_progress_status_ids: in_progress_status_ids,
                                         waiting_status_ids: waiting_status_ids, next_issue_ids: next_issue_ids)
  end
end

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


# Plain stand-ins for Redmine versions and issues, so the stage and percent rules are tested without a database.
module StageDoubles
  VersionDouble = Struct.new(:id, :name, :effective_date, :status, keyword_init: true) do
    def closed?
      status == "closed"
    end
  end

  IssueDouble = Struct.new(:id, :fixed_version_id, :status_id, :closed, keyword_init: true) do
    def closed?
      closed
    end
  end

  OPEN_STATUS_ID = 1
  IN_PROGRESS_STATUS_ID = 2
  CLOSED_STATUS_ID = 5

  def version(id, name, effective_date = nil, status: "open")
    VersionDouble.new(id: id, name: name, effective_date: effective_date, status: status)
  end

  def open_issue(id, version_id, status_id: OPEN_STATUS_ID)
    IssueDouble.new(id: id, fixed_version_id: version_id, status_id: status_id, closed: false)
  end

  def closed_issue(id, version_id)
    IssueDouble.new(id: id, fixed_version_id: version_id, status_id: CLOSED_STATUS_ID, closed: true)
  end

  def stage_list(versions, issues)
    RubylodeProgress::StageList.new(versions: versions, issues: issues, in_progress_status_ids: [IN_PROGRESS_STATUS_ID])
  end
end

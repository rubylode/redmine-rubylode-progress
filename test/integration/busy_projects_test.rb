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

# Slice 19, steps 1 to 3: the fold of finished stages, the top track with many stages, the version tick list.
class BusyProjectsTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  FOLD = "details.rubylode-progress-finished-fold"
  CLOSED_STATUS_ID = 5
  PROJECT_PAGE_QUERY_CEILING = 51 # the same ceiling as QueryCountTest

  setup do
    @manager = User.find(2)
    Role.find(1).add_permission!(:view_rubylode_progress)
    Role.find(2).add_permission!(:view_rubylode_progress)
    Role.find(2).remove_permission!(:edit_project)
    log_user("jsmith", "jsmith")
  end

  # finished: closed versions with closed issues (done stages); the current stage (one closed, one open issue) and one
  # upcoming stage follow, so the project has finished + 2 stages.
  def build_project(finished:, name: "Busy", issues_per_stage: 2)
    project = Project.generate!(name: name, is_public: false)
    project.enable_module!(:rubylode_progress)
    project.enable_module!(:issue_tracking)
    User.add_to_project(@manager, project, Role.find(1))
    @versions = Array.new(finished) do |index|
      version = Version.generate!(project: project, name: "Finished #{index + 1}",
                                  effective_date: Date.new(2025, 1, 1) >> index)
      issues_per_stage.times { Issue.generate!(project: project, fixed_version: version, author: @manager, status_id: CLOSED_STATUS_ID) }
      version.update!(status: "closed")
      version
    end
    current = Version.generate!(project: project, name: "Current stage", effective_date: Date.new(2031, 1, 1))
    Issue.generate!(project: project, fixed_version: current, author: @manager, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: project, fixed_version: current, author: @manager)
    upcoming = Version.generate!(project: project, name: "Upcoming stage", effective_date: Date.new(2031, 2, 1))
    Issue.generate!(project: project, fixed_version: upcoming, author: @manager)
    project
  end

  def progress_path(project) = "/projects/#{project.identifier}/progress"

  test "a project with more than the kept finished stages gets one fold row with the combined numbers" do
    project = build_project(finished: 8)

    get progress_path(project)

    assert_response :success
    assert_select FOLD, count: 1
    assert_select "#{FOLD}[id=?]", "rubylode-progress-finished-fold"
    assert_select "#{FOLD} > summary .rubylode-progress-stage__name", text: "5 finished stages"
    assert_select "#{FOLD} > summary .rubylode-progress-meter__percent", text: "100%"
    assert_select "#{FOLD} > summary .rubylode-progress-stage__summary", text: "10 issues closed"
    assert_select "#{FOLD} .rubylode-progress-stage", count: 5
    assert_select "#{FOLD}[open]", count: 0
    assert_select ".rubylode-progress-stage", count: 10 # 5 folded + 3 kept + current + upcoming
    assert_select ".rubylode-progress-stage-list > ol > .rubylode-progress-stage-item > .rubylode-progress-stage", count: 5
  end

  test "the fold opens to the stages exactly as they render on their own" do
    project = build_project(finished: 6)

    get progress_path(project)

    assert_select "#{FOLD} .rubylode-progress-stage__name", text: "Finished 1"
    assert_select "#{FOLD} .rubylode-progress-stage__name", text: "Finished 3"
    assert_select "#{FOLD} .rubylode-progress-stage__name", text: "Finished 4", count: 0
    assert_select ".rubylode-progress-stages > .rubylode-progress-stage-item .rubylode-progress-stage__name", text: "Finished 4"
  end

  test "a small project is unchanged: no fold, every stage listed, every stage labelled" do
    project = build_project(finished: 3)

    get progress_path(project)

    assert_select FOLD, count: 0
    assert_select ".rubylode-progress-stage", count: 5
    assert_select ".rubylode-progress-track__stage", count: 5
    assert_select ".rubylode-progress-track__label", count: 5
    assert_select ".rubylode-progress-track__ellipsis", count: 0
  end

  test "the number of finished stages kept is a project setting with a plugin-wide default" do
    project = build_project(finished: 6)
    RubylodeProgress::ProjectSetting.create!(project: project, finished_stages_kept: 1)

    get progress_path(project)

    assert_select "#{FOLD} > summary .rubylode-progress-stage__name", text: "5 finished stages"

    RubylodeProgress::ProjectSetting.where(project_id: project.id).update_all(finished_stages_kept: nil)
    with_settings(plugin_redmine_rubylode_progress: RubylodeProgress::Settings::DEFAULTS.merge("finished_stages_kept" => "5")) do
      get progress_path(project)
      assert_select FOLD, count: 0 # 6 finished, 5 kept: one to fold is no fold
    end
  end

  test "the track over 12 stages has the ellipsis, full labels only near the current stage, and a label per mark" do
    project = build_project(finished: 14)

    get progress_path(project)

    assert_response :success
    assert_select "ol.rubylode-progress-track[aria-label*=?]", "14 of 16 stages finished"
    # first folded mark, the ellipsis, 3 kept finished, current, upcoming
    assert_select "ol.rubylode-progress-track > li", count: 7
    assert_select "ol.rubylode-progress-track > li.rubylode-progress-track__stage--summary", count: 1
    assert_select "a.rubylode-progress-track__ellipsis[href=?]", "#rubylode-progress-finished-fold" do |links|
      assert_equal "Show the 11 finished stages", links.first["aria-label"]
      assert_equal "Show the 11 finished stages", links.first["title"]
      assert_select links.first, ".rubylode-progress-track__dot", count: 3
    end
    assert_select ".rubylode-progress-track__stage--summary .rubylode-progress-track__name", text: "11 stages done"
    # full labels (name, percent, date): the last kept stage, the current stage and the upcoming one
    assert_select ".rubylode-progress-track__percent", count: 3
    assert_select ".rubylode-progress-track__name", text: "Current stage"
    # every other stage mark has a title and a hidden label
    assert_select "ol.rubylode-progress-track > li[title]", count: 3
    assert_select "ol.rubylode-progress-track > li[title] .rubylode-progress-visually-hidden", count: 3
    assert_select "ol.rubylode-progress-track > li[title=?]", "Finished 1, 100%, Done"
    # one label per mark
    assert_select "ol.rubylode-progress-track > li" do |items|
      items.each do |item|
        assert_equal 1, item.css(".rubylode-progress-track__label, .rubylode-progress-visually-hidden").count { |node| node.parent == item }
      end
    end
  end

  test "up to 12 stages the track is as before" do
    project = build_project(finished: 10) # 12 stages

    get progress_path(project)

    assert_select "ol.rubylode-progress-track > li", count: 12
    assert_select ".rubylode-progress-track__label", count: 12
    assert_select ".rubylode-progress-track__ellipsis", count: 0
    assert_select "ol.rubylode-progress-track > li[title]", count: 0
    assert_select FOLD, count: 1 # the list still folds; only the track keeps its marks
  end

  test "the cross-project page keeps its compact tracker with every stage" do
    build_project(finished: 14)

    get "/progress"

    assert_select ".rubylode-progress-compact-tracker .rubylode-progress-track__stage", count: 16
    assert_select ".rubylode-progress-track__ellipsis", count: 0
  end

  # --- the version tick list ---

  def save_ticks(project, ticked_ids)
    patch "/projects/#{project.identifier}/progress/settings",
          params: { rubylode_progress_project_setting: { counted_version_ids: [""] + ticked_ids.map(&:to_s) } }
  end

  test "the migration adds the columns and an old row reads as all versions counted" do
    columns = RubylodeProgress::ProjectSetting.column_names
    assert_includes columns, "excluded_version_ids"
    assert_includes columns, "finished_stages_kept"

    project = build_project(finished: 2)
    RubylodeProgress::ProjectSetting.create!(project: project, checklist_grouping: "category")
    assert_nil RubylodeProgress::ProjectSetting.find_by!(project_id: project.id).excluded_version_ids
    assert_empty RubylodeProgress::EffectiveSettings.for(project.reload).excluded_version_ids

    get progress_path(project)
    assert_select ".rubylode-progress-stage", count: 4
  end

  test "the settings tab lists the counted versions ticked and saves the unticked ones" do
    project = build_project(finished: 3)
    first_version = @versions.first
    get "/projects/#{project.identifier}/settings/rubylode_progress"
    assert_select "input[type=checkbox][name=?][checked]", "rubylode_progress_project_setting[counted_version_ids][]", count: 5

    save_ticks(project, project.versions.pluck(:id) - [first_version.id])
    assert_redirected_to "/projects/#{project.identifier}/settings/rubylode_progress"

    assert_equal [first_version.id], RubylodeProgress::ProjectSetting.find_by!(project_id: project.id).excluded_version_ids
    get "/projects/#{project.identifier}/settings/rubylode_progress"
    assert_select "input[type=checkbox][name=?][checked]", "rubylode_progress_project_setting[counted_version_ids][]", count: 4
    assert_select "input[type=checkbox][value=?]:not([checked])", first_version.id.to_s
  end

  test "an unticked version is not a stage and its issues are not counted" do
    project = build_project(finished: 3)
    save_ticks(project, project.versions.pluck(:id) - [@versions.first.id])

    get progress_path(project)

    assert_select ".rubylode-progress-stage__name", text: "Finished 1", count: 0
    assert_select ".rubylode-progress-stage", count: 4
    assert_select ".rubylode-progress-step", count: 2 * 2 + 3
    assert_select "ol.rubylode-progress-track > li", count: 4
  end

  test "ticking everything again clears the list, and a new version is counted as it appears" do
    project = build_project(finished: 3)
    save_ticks(project, project.versions.pluck(:id) - [@versions.first.id])
    save_ticks(project, project.versions.pluck(:id))
    assert_nil RubylodeProgress::ProjectSetting.find_by!(project_id: project.id).excluded_version_ids

    save_ticks(project, project.versions.pluck(:id) - [@versions.first.id])
    late = Version.generate!(project: project, name: "Added later", effective_date: Date.new(2032, 1, 1))
    Issue.generate!(project: project, fixed_version: late, author: @manager)

    get progress_path(project)
    assert_select ".rubylode-progress-stage__name", text: "Added later"
  end

  test "ids posted that are not the project's versions are ignored, and so are ticks of deleted versions" do
    project = build_project(finished: 3)
    first_version = @versions.first
    foreign = build_project(finished: 1, name: "Elsewhere").versions.first
    save_ticks(project, project.versions.pluck(:id) - [first_version.id] + [foreign.id, 999_999])
    assert_equal [first_version.id], RubylodeProgress::ProjectSetting.find_by!(project_id: project.id).excluded_version_ids

    first_version.destroy
    RubylodeProgress::ProjectSetting.find_by!(project_id: project.id).update_columns(excluded_version_ids: [first_version.id, 999_999].to_json)

    get progress_path(project)
    assert_response :success
    assert_select ".rubylode-progress-stage", count: 4
  end

  test "someone without Edit project cannot save the tick list" do
    project = build_project(finished: 2)
    User.add_to_project(User.find(3), project, Role.find(2))
    post "/logout"
    log_user("dlopper", "foo")

    save_ticks(project, [])

    assert_response :forbidden
    assert_nil RubylodeProgress::ProjectSetting.find_by(project_id: project.id)
  end

  test "the counted-versions prefix still applies after the tick list" do
    project = build_project(finished: 3)
    RubylodeProgress::ProjectSetting.create!(project: project, counted_versions: "prefix", version_name_prefix: "Finished",
                                             excluded_version_ids: [@versions.first.id])

    get progress_path(project)

    assert_select ".rubylode-progress-stage__name", text: "Finished 1", count: 0
    assert_select ".rubylode-progress-stage__name", text: "Current stage", count: 0
    assert_select ".rubylode-progress-stage", count: 2
  end

  test "the plugin-wide page has the number but no version list" do
    post "/logout"
    log_user("admin", "admin")

    get "/settings/plugin/redmine_rubylode_progress"

    assert_select "input[name=?]", "settings[finished_stages_kept]"
    assert_select "input[name*=counted_version_ids]", count: 0
  end

  # --- cache and queries ---

  test "the stage cache key changes with the tick list but not with the number of finished stages kept" do
    project = build_project(finished: 2)
    project.reload
    stage_key = lambda do |settings|
      progress = RubylodeProgress::ProjectProgress.new(project: project, viewer: @manager, settings: settings)
      RubylodeProgress::StageCacheKey.for(stage: progress.stages.last, project: project, viewer: @manager, settings: settings,
                                          editable_issue_ids: Set.new, new_issue_mode: :none, accepts_issues: false,
                                          can_manage_version: false)
    end
    base = RubylodeProgress::EffectiveSettings.for(project)
    more_kept = base.with(finished_stages_kept: 9)
    unticked = base.with(excluded_version_ids: [@versions.first.id])

    assert_equal stage_key.call(base), stage_key.call(more_kept)
    refute_equal base.cache_digest, unticked.cache_digest
  end

  test "the project page runs the same number of queries for 14 stages as for 40, and for few issues as for many" do
    counts = [[14, 1], [40, 1], [14, 8]].map do |finished, per_stage|
      project = build_project(finished: finished, issues_per_stage: per_stage, name: "Counted #{finished}-#{per_stage}")
      get progress_path(project)
      assert_response :success
      QueryCounter.count { get progress_path(project) }
    end

    assert_equal [counts.first], counts.uniq, "query counts by stage and issue count: #{counts.inspect}"
    assert_operator counts.first, :<=, PROJECT_PAGE_QUERY_CEILING
  end
end

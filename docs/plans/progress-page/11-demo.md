# 11. Demo data and bin/demo

Blocked by slices 6, 7 and 8.

## Done means

`rake redmine_rubylode_progress:demo` builds a demo project with five versions and about forty issues covering every
stage state and every checklist status, plus a few smaller projects for `/progress`; `ruby bin/demo up` starts a
throwaway Redmine 7 with this folder mounted as the plugin and runs it.

## Steps

1. `lib/rubylode_progress/demo_data.rb`: `DemoData.build(today: Date.current)`, one transaction, does nothing when the
   demo project exists (as Projects' `test/seed.rb`). Everything made up: plain-noun project and version names, people
   named after computer scientists of the past as Projects does; check that no name, title or date matches the private
   reference before committing.
   - Main project with the module enabled and subproject roll-up exercised by one subproject. Five versions, dated
     relative to `today`: two closed, one current with most steps done, two upcoming (one locked).
   - About forty issues: closed ones in the done stages; in the current stage some closed, one in an in-progress
     status, three or more open to show the Next limit, one blocked by an open issue, one assigned to the demo person
     and one to a group the demo person is in; notes on some, one private.
   - Plugin settings: an in-progress status and a waiting status chosen; the main project overrides grouping to
     category.
   - Three smaller projects with fewer versions: one all done, one not started, one without versions.
   - A demo person (`demo-password-1`, as the siblings) with a role holding "View progress".
2. `lib/tasks/redmine_rubylode_progress.rake`: `namespace :redmine_rubylode_progress { task demo: :environment }`,
   printing what it built or "already loaded".
3. `docker-compose.yml`: a `redmine` service on `redmine:7.0.2`, `RAILS_ENV: production`, port `127.0.0.1:3016:3000`
   (Plan's call: the next free port after the siblings' 3007 to 3015 and 3017), this folder mounted at
   `plugins/redmine_rubylode_progress`, named volumes for files and SQLite; the `test` service from slice 1.
4. `bin/demo` from Beszel's and Projects': `up` (start, wait for `/login`, `bin/rails redmine:plugins:migrate`, then
   `bin/rails redmine_rubylode_progress:demo`), `seed`, `restart`, `down`, `reset`; usage printed from the header.

## Tests, in order (`test/integration/demo_data_test.rb`)

1. "the demo builds five versions and between 35 and 45 issues in the main project".
2. "the demo shows every stage state": a done, a current and an upcoming stage for the demo person.
3. "the demo shows every checklist status": Done, Needs you, Waiting, Next and To do each at least once for the demo
   person.
4. "the cross-project page lists the main project and the three smaller ones".
5. "running the demo twice changes nothing".

## Not in this slice

Screenshots (12); a fake external service (none is needed).

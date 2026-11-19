# 12. README, CHANGELOG, listing and release 1.0.0

Blocked by slices 9, 10, 11, 13, 14, 15, 16 and 17.

## Done means

The README covers install, enabling the module, every setting and screenshots taken from the demo; CHANGELOG, thumbnail,
`docs/releasing.md` and the redmine.org listing text exist as the siblings have them; tag `v1.0.0` is on a green suite
and released through `/rubylode:prepare-release` (Gitea origin, the publish job, the GitHub release, the redmine.org kit).

## Steps

1. Screenshots from the demo with Beszel's `package.json`, `script/browser.mjs` and `script/demo_screenshots.mjs`:
   `progress-tab.png`,
   `progress-needs-you.png`, `progress-phone.png`, `progress-dark.png`, `all-projects.png`, `project-settings.png` in
   `docs/screenshots/`. `docs/thumbnail.png` already exists (drawn by the shared generator in `rubylode-themes`, glyph
   `rail`); do not replace it with a screenshot. Check each image against the private reference for any
   name, title or date before committing.
2. `README.md` laid out like Beszel's: title and badges, What it does, Install (copy to `plugins/`, `bundle exec rake
   redmine:plugins:migrate`, restart), Enabling it (the module "Rubylode Progress", the permission "View progress"),
   Settings (every setting and the project tab, who may save it), Where it shows (the tab, `/progress`), The rules
   behind the page (scope, stages, current stage, percent, derived status, Next limit, in the words of the design),
   Restyling it (link to `docs/theming.md`), Troubleshooting, Tests, Try it (`bin/demo`), Releasing, License.
3. `CHANGELOG.md`, Keep a Changelog form, `## [1.0.0] - <date>`, Added items for each page, the filters, the
   settings and the demo.
4. `docs/releasing.md` and `docs/redmine-org-listing.md` from Projects' and Beszel's: name "Rubylode Progress", author
   "Rubylode", compatible with Redmine 7.0.x only, file `redmine_rubylode_progress-1.0.0.zip`.
5. `.github/workflows/release.yml` and `security.yml` arrived with slice 1; check `.gitattributes` leaves out `docs`,
   `docker`, `docker-compose.yml`, `package.json`, `script`, `.github`.
6. Before the tag, the release rules' leak check (every revision, zero hits for private names and tool paths). Then
   `/rubylode:prepare-release`: version 1.0.0 everywhere, `bin/test`, the tag pushed to the Gitea origin when the owner
   asks, the GitHub release checked by its assets, and the redmine.org kit.

## Tests

1. Unit `locale_structure_test.rb` from Projects': every key used in a view exists in `en.yml`.
2. Unit "the version in init.rb has a CHANGELOG entry".

## Not in this slice

The redmine.org upload (the owner pastes the kit). Installing on a production Redmine. The remotes exist from the
plugin's setup (`/rubylode:setup-new-plugin`, 2026-11-18): private Gitea origin, GitHub fed only by the publish job.

# Releasing

Push a `vX.Y.Z` tag whose version matches `version` in `init.rb` and that has an entry in `CHANGELOG.md`. The release
workflow runs the tests on Redmine 7.0.2 and 7.0-stable with Ruby 3.4 and 4.0, builds `redmine_rubylode_progress-X.Y.Z.zip`
(with a checksum file) and publishes the GitHub release with that changelog entry as its notes. To build a release for a tag
that already exists, open Actions, choose release, Run workflow, and enter the tag.

The zip is made with `git archive`, so what `.gitattributes` marks `export-ignore` (docs, docker, script, the demo, the
workflows) stays out of it and the plugin folder holds only what Redmine needs.

The text for the www.redmine.org listing, and how to read the result of Check for updates, is in [docs/redmine-org-listing.md](redmine-org-listing.md).

# 6. Filters, the remembered preference and the Stimulus controller

Blocked by slice 5.

## Done means

Open (default), Needs you, Done and All are links (`?filter=needs_you`) that work without JavaScript; with it, the
checklist is swapped in place and the pressed filter carries `aria-pressed="true"`; the choice is kept per person in a
Redmine user preference.

## Steps

1. First, confirm the registration path on the demo or the test image: the page's `script[type=importmap]` lists
   `@hotwired/stimulus` and `controllers/application`, and a module script from the plugin can import
   `application` and register. Redmine 7.0.2's source says yes (see the plan's README) and Rubylode To-do does it.
   Fallback, only if that fails: a plain script loaded through the `view_layouts_base_html_head` hook, as Rubylode
   Projects loads `overview.js`, doing the same fetch and swap without Stimulus.
2. `app/models/rubylode_progress/checklist_filter.rb`: `ChecklistFilter::NAMES = %w[open needs_you done all].freeze`,
   `DEFAULT = "open"`, `PREFERENCE_KEY = :rubylode_progress_checklist_filter`; `ChecklistFilter.resolve(requested:,
   remembered:)` returns a valid name (requested if valid, else remembered if valid, else `"open"`);
   `ChecklistFilter.apply(name, items)`: open = not Done, needs_you, done, all.
3. Controller: `#show` and `#checklist` resolve the filter from `params[:filter]` and `User.current.pref[PREFERENCE_KEY]`;
   when the viewer is logged in and a valid `params[:filter]` differs from the stored one, store it
   (`pref[PREFERENCE_KEY] = name; pref.save`). `#checklist` renders `rubylode_progress/_checklist` with `layout: false`.
   Plan's call: the tiles stay unfiltered (they count the whole scope) and are not swapped.
4. `app/views/rubylode_progress/_filters.html.erb`: a `<nav>` of four links, each with `href` `?filter=<name>`,
   `data-checklist-path` (the checklist route with the filter) and `aria-pressed`.
5. `assets/javascripts/progress_filters.js`, loaded in `show` with `javascript_include_tag "progress_filters", plugin:
   "redmine_rubylode_progress", type: "module"` inside `content_for :header_tags`:
   `import { Controller } from "@hotwired/stimulus"`, `import { application } from "controllers/application"`,
   `class ProgressFiltersController` with targets `checklist` and `filter`, action `choose(event)`: prevent default,
   fetch `data-checklist-path` with `credentials: "same-origin"`, replace the checklist target's children, set
   `aria-pressed` on every filter, `history.replaceState` to the link's `href`; on a failed fetch follow the link.
   `application.register("rubylode-progress-filters", ProgressFiltersController)`. GPL comment header as
   `overview.js` has.

## Tests, in order

1. Unit `checklist_filter_test.rb`: "a valid request wins over the remembered filter"; "a missing request uses the
   remembered one"; "Open is the default"; "each filter keeps the right items".
2. Review Focus 5, "a remembered filter that no longer exists falls back to Open": stored `"waiting"`, no request; the
   page shows Open pressed and the stored value is left alone (not rewritten on a plain visit).
3. Integration `test/integration/filters_test.rb`: "?filter=done shows only done rows and presses Done".
4. "choosing a filter is remembered for the next visit without a parameter".
5. "two people keep their own filters".
6. "an anonymous visitor can filter and nothing is stored".
7. "the checklist route returns the checklist alone, without the layout, and checks the permission" (403 for a
   non-member).
8. "the page loads the filter script as a module and the import map names what it imports".
9. "an unknown filter in the address shows Open".

## Not in this slice

Settings (7), caching (9), the filter pills' look (10).

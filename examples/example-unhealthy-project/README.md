# example-unhealthy-project

A **real, runnable Rails 8 app that is intentionally unhealthy** — the fixture used to
demonstrate the `rails-health-audit` skill. Unlike a hand-written skeleton, this app
actually `bundle install`s, so **every** tool in the audit produces a real finding
(including `license_finder` and `bundle outdated`, which need an installed bundle and the
project's own Ruby — they would otherwise show "skipped").

> ⚠️ Everything here is broken **on purpose**. Do not copy any of it into real code.

## Run the audit on it

```sh
bash ../../scripts/audit.sh .
open tmp/health-audit/report-*/health-audit-report.pdf
```

`audit.sh` runs the static scan and then best-effort runs the runtime scan, producing one
combined `health-audit-report.md` (and, after export, `health-audit-report.pdf`). A
committed sample run already lives in `tmp/health-audit/report-*/` with the Action plan
filled in, so you can see the deliverable without running anything.

## Problems planted in it (and which tool catches each)

| Where | Problem | Caught by |
|-------|---------|-----------|
| `app/controllers/products_controller.rb:28` | Command injection — `system("convert #{thumb} …")` | brakeman (High) |
| `app/controllers/products_controller.rb:8,10` | SQL injection — interpolated params in `where` / `connection.execute` | brakeman (High) |
| `app/views/products/index.html.erb:4` | XSS — `params[:q].html_safe` | brakeman (High) |
| `app/controllers/products_controller.rb:16` | Mass assignment — `Product.new(params[:product])` | brakeman / review |
| `app/controllers/application_controller.rb` | CSRF protection disabled | review |
| `Gemfile` (`jwt 2.3.0`, `rexml 3.2.4`) | Pinned to versions with known CVEs | bundler-audit |
| (whole bundle) | 73 dependencies with no license decision | license_finder |
| `app/models/report.rb` | Slow Ruby idioms (`select{}.first`, `reverse.each`) | fasterer |
| `app/models/product.rb` | Law of Demeter, feature envy, complex/uncommunicative `#s` | rubycritic |
| `app/controllers/products_controller.rb:35` | `rescue Exception` swallows everything | rails_best_practices |
| `app/controllers/products_controller.rb` | Fat controller; duplicated create/update logic | rails_best_practices / flay |
| `app/views/products/index.html.erb` | Messy ERB (tag spacing, no final newline) | erb_lint |
| `config/routes.rb` | Verb confusion (`via: :all`) | brakeman / rails_best_practices |
| (style, app-wide) | Spacing / layout offenses | rubocop |

## Runtime (Phase 2) — the DB is intentionally broken too

The schema (`db/migrate/`, `db/schema.rb`) is planted with data-integrity problems so the
runtime scan also lights up. `audit.sh` runs Phase 2 automatically, but it can only do so
once the database exists — so set up the DB first, then run the audit:

```sh
bin/rails db:prepare
bash ../../scripts/audit.sh .
```

| Where | Problem | Caught by |
|-------|---------|-----------|
| `products.owner_id`, `tags.product_id` | `belongs_to` columns with no foreign key | active_record_doctor (missing_foreign_keys) |
| `products.owner_id`, `tags.product_id` | foreign-key columns with no index | active_record_doctor (unindexed_foreign_keys) + lol_dba |
| `products.name` (presence-validated), `tags.product_id` | nullable column the model treats as required | active_record_doctor (missing_non_null_constraint) |
| `products.sku` (uniqueness-validated) | no unique index backing the validation | active_record_doctor (missing_unique_indexes) |

A committed sample of the report (runtime results folded into section 3) is in
`tmp/health-audit/report-*/health-audit-report.pdf`.

## Why a real app instead of a skeleton

A trimmed skeleton can't `bundle install`, so `license_finder` and `bundle outdated` can
only ever report "skipped" — which looks like the tool is broken. A real bundle-installed
app exercises the whole pipeline end to end, exactly as it would on a production codebase.

# legacy_blog — intentionally unhealthy sample app

This is **not** a real application. It is a tiny, deliberately broken Rails-shaped
codebase used to demonstrate `rails-health-audit`. Every file contains planted
problems so the audit has something to find.

What is planted, by severity rank:

| Rank | Category | Planted problem | Where |
|------|----------|-----------------|-------|
| 1 | Security | SQL injection, command injection | `posts_controller.rb` |
| 1 | Security | XSS via `html_safe` | `views/posts/index.html.erb` |
| 1 | Security | CSRF protection disabled, mass assignment | `application_controller.rb`, `posts_controller.rb` |
| 1 | Security | EOL Rails 4.1 + known-vulnerable gems | `Gemfile.lock` |
| 2 | Data correctness | missing index / FK / unique index | `db/schema.rb` (Phase 2) |
| 3 | Performance | N+1 in the view | `views/posts/index.html.erb` |
| 4 | Maintainability | fat method, duplication, Law of Demeter | `posts_controller.rb`, `post.rb` |

Run the audit against it:

```sh
bash ../../scripts/audit.sh .
cat tmp/health-audit/REPORT.md
```

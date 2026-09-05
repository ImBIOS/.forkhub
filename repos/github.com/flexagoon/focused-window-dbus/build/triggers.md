# Triggers — github.com/flexagoon/focused-window-dbus

> An agent MUST ask the user explicitly which triggers to enable.
> Triggers affect LLM token consumption and CI/compute spend — never assume.

- [ ] `push` (default ON): build on every push to `repos/github.com/flexagoon/focused-window-dbus/**`
- [ ] `schedule` (default ON, daily `0 6 * * *`): poll upstream releases.
  Increase cadence only with user approval.
- [ ] `workflow_dispatch` (always ON): manual + `fh`-triggered rebuilds.

Decision log:

| date | who | decision | reason |
|---|---|---|---|
| | | | |

To change cadence/scope, edit `.github/workflows/forkhub-build.yml` (cron)
or pass `target` to manual dispatches. This file is the record of intent.

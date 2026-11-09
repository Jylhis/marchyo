# Reporting a Crash Upstream to Marchyo

Read this only after concluding that a crash is genuinely Marchyo's to fix.

## Is it even Marchyo's bug?

Be strict here. Marchyo is a configuration layer over NixOS, so a crash inside a
third-party application (a file manager, a browser, a GNOME or Qt library) is
almost always an upstream bug in that project, not in Marchyo.

Marchyo's sphere of control is roughly:

- the `marchyo` CLI (`packages/marchyo-cli`)
- the Quickshell shell (`shell/`) and its plugins
- the Hyprland, terminal and Home Manager configuration it generates
- its themes
- its NixOS and Home Manager modules, and the options they expose
- how it packages and configures what it installs

A crash in a program Marchyo merely installs is not a Marchyo bug unless
Marchyo's own packaging or configuration is implicated, for example a wrong
environment variable or a missing runtime dependency in a wrapper.

If it is not Marchyo's, say so and stop. Suggesting the right upstream project
is useful; filing there yourself is not part of this.

## Three conditions, all required

1. It is a verified bug in Marchyo's sphere, established on evidence. Issues are
   for verified bugs only.
2. The user has explicitly agreed. Show them the exact title and body you
   propose, and wait for a yes. Never file unprompted.
3. The machine can file it: `gh auth status` must succeed. If `gh` is missing
   or unauthenticated, do not install or authenticate it. Say so, and hand the
   user the finished text to submit themselves.

## Search before filing

A duplicate issue costs a maintainer more time than no report at all.

```bash
gh search issues --repo Jylhis/marchyo "<program> crash"
gh issue list --repo Jylhis/marchyo --state all --search "<signal> <program>"
```

Search on the crashing program, the signal, and distinctive symbols from the
backtrace, not on the wording of the title you were about to write. Include
closed issues: a match closed as fixed, when the crash still reproduces on a
current system, is a regression, and reporting that is worth far more than
another duplicate.

## Adding to an existing report

If a plausible match comes back, read it properly first:

```bash
gh issue view <number> --repo Jylhis/marchyo --comments
```

Confirm it is the same failure. The same program crashing is not the same bug if
the trigger or the stack differs. If it is the same, comment only when you have
something the thread lacks: a different reproduction, a symbolized stack, a
narrower trigger, a version where it regressed. A comment that only says it
happens to you too is noise; tell the user and file nothing.

## Redact before filing

An issue is public. Before showing the user the text to approve, remove anything
that grants access or identifies them: tokens, API keys and passwords in command
lines, environment variables and URLs; usernames and home directories in paths
(write `$HOME`); hostnames, IP addresses and email addresses; anything from the
core's memory. Quote only the frames and lines the report needs, and say what you
removed.

## Filing a new issue

Only when the search turns up nothing that matches:

```bash
gh issue create --repo Jylhis/marchyo --title "..." --body "..."
```

Include what happened, what was expected, steps to reproduce, the output of
`marchyo status`, and diagnostics from `marchyo debug`. `gh` cannot attach media;
if a screenshot would help, save one and give the user the path.

## Signing

End the issue or comment with a line naming the model and agent harness that
produced it, so a human reader knows it was machine-authored:

> Filed by \<model name\> via \<agent harness\>.

Use your actual model and harness names. If you are not certain of them, say so
plainly rather than inventing a version string.

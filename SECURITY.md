# Security Policy

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Instead, report them privately via [GitHub's private vulnerability reporting](https://github.com/eylonshm/claude-usage-widget/security/advisories/new).

I'll respond as quickly as possible and coordinate a fix before any public disclosure.

## Scope

This app reads local files (`~/.claude/stats-cache.json`) and runs the Claude Code CLI. It does not make network requests to external services, store credentials, or require any API keys. The attack surface is intentionally minimal.

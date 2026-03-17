# Platform Agnostic

All features must work out-of-the-box for any user who installs the app, without manual configuration.

**Rules:**
- Never hardcode user-specific values (org IDs, usernames, paths, tokens, UUIDs)
- Never rely on a specific browser being installed or a specific browser profile
- Never rely on a specific project directory existing — fall back gracefully
- Credentials must be read from standard system locations (keychain, `~/.claude/`, etc.) or auto-discovered
- Test that new data sources / auth approaches work for an arbitrary user, not just the current developer's environment

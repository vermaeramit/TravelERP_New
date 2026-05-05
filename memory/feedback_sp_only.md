---
name: Stored procedures only
description: All DB access must use stored procedures, not inline SQL
type: feedback
---

Use only stored procedures for all database queries in this project — no inline SQL strings in repositories.

**Why:** User explicitly corrected when inline SQL was used mid-build.

**How to apply:** Every repository method calls `CommandType.StoredProcedure` with a named SP. When adding new data access, create the SP in the relevant Database/Tenant or Database/Master SQL file, then call it from the repository.

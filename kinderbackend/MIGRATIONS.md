# Database Migrations

This backend uses [Alembic](https://alembic.sqlalchemy.org/) for schema migrations against the
SQLAlchemy models in `models.py` / `admin_models.py`.

## Common commands

Run from the `kinderbackend/` directory:

```bash
# Apply all pending migrations
python -m alembic upgrade head

# Create a new migration after changing a model
python -m alembic revision --autogenerate -m "describe the change"

# Inspect current/expected head revisions
python -m alembic current
python -m alembic heads
```

## Startup behavior

`main.py` calls `db_migrations.verify_database_schema()` on application startup. It:

- Raises a `RuntimeError` and refuses to start if the migration scripts in `alembic/versions/`
  resolve to more than one head (i.e. an unmerged branch) or to zero heads.
- Raises a `RuntimeError` if the database's current revision doesn't match the single expected
  head, telling you to run `python -m alembic upgrade head`.
- Two environment variables (documented in `.env.example`) change this behavior:
  - `SKIP_SCHEMA_VERIFY=true` skips the check entirely (local/dev convenience only).
  - `AUTO_RUN_MIGRATIONS=true` runs `alembic upgrade head` automatically instead of raising —
    not recommended for production; prefer running migrations as an explicit release step.

## Branch hygiene

Alembic allows multiple migrations to share the same `down_revision`, which lets independent
features branch off the same point and get joined later by a merge revision (`down_revision`
as a tuple). That flexibility has a sharp edge: a merge revision only unifies the *graph*, it does
not reconcile column-level intent between the branches it joins. See
`alembic/versions/ab1c2d3e4f50_restore_subscription_lifecycle_columns.py` for a real example —
one branch dropped columns from `subscription_profiles` immediately after the initial schema,
while a sibling branch later recreated the table with those same columns; both were valid
on their own, but merging them silently left the columns missing depending on application order.

Before merging two heads, diff the schema each branch produces (e.g. by applying each branch to
a throwaway SQLite database and comparing `PRAGMA table_info`) rather than assuming a merge
revision with `pass` in `upgrade()` is automatically safe.

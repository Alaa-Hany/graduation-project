# Developer Workflow

This guide documents the current local engineering workflow for Kinder World after the recent CI and quality-gate upgrades.

## 1. What Changed

The project now has explicit local and CI checks for:

- Backend: `ruff`, `black`, `isort`, `mypy`, `pytest`, `pytest-cov`
- Flutter: `flutter analyze`, `flutter test --coverage`
- Coverage policy summaries for backend and Flutter

The goal is simple:

- run the same checks locally that CI will run
- understand failures faster
- keep quality tooling lightweight enough for everyday use

## 2. Recommended Local Entry Point

Use the shared task runner from the repository root:

```bash
python tools/dev.py <command>
```

Available commands:

- `backend-install`
- `backend-lint`
- `backend-test`
- `backend-test --coverage`
- `backend-checks`
- `flutter-install`
- `flutter-analyze`
- `flutter-test`
- `flutter-test --coverage`
- `flutter-checks`
- `all-checks`

Examples:

```bash
python tools/dev.py backend-install
python tools/dev.py backend-checks
python tools/dev.py backend-test --coverage
python tools/dev.py flutter-install
python tools/dev.py flutter-checks
python tools/dev.py flutter-test --coverage
```

## 3. First-Time Setup

### Backend

```bash
cd kinderbackend
python -m venv .venv
```

Windows:

```bash
.venv\Scripts\activate
```

Linux/macOS:

```bash
source .venv/bin/activate
```

Then install dev dependencies:

```bash
python ../tools/dev.py backend-install
```

### Flutter

Make sure Flutter is installed and on `PATH`, then run:

```bash
python tools/dev.py flutter-install
```

## 4. Daily Workflow

For a backend-focused change:

1. Activate the backend virtual environment.
2. Run:

```bash
python tools/dev.py backend-lint
python tools/dev.py backend-test
```

3. If the change affects auth, sessions, settings, or behavior used in CI gates, run:

```bash
python tools/dev.py backend-test --coverage
```

For a Flutter-focused change:

1. Run:

```bash
python tools/dev.py flutter-analyze
python tools/dev.py flutter-test
```

2. If the change affects testable features or repositories, run:

```bash
python tools/dev.py flutter-test --coverage
```

For cross-stack changes:

```bash
python tools/dev.py all-checks
```

## 5. Optional Pre-Commit Hooks

Pre-commit is optional, but recommended for backend contributors who want fast feedback before creating commits.

Install it in the same Python environment used for backend tooling:

```bash
pip install pre-commit
pre-commit install
```

Current hooks cover:

- trailing whitespace cleanup
- end-of-file fixes
- `ruff`
- `black`
- `isort`

The hooks intentionally do **not** run:

- `mypy`
- `pytest`
- Flutter commands

Those checks are still better suited for explicit local runs and CI because they are slower and more context-heavy.

## 6. Understanding Common Failures

### Backend

`ruff check .`

- Usually means a real lint or unused import issue.
- Fix the code rather than suppressing the rule unless there is a clear reason.

`black --check .`

- Means formatting drift.
- Fix with:

```bash
black .
```

`isort --check-only .`

- Means import order drift.
- Fix with:

```bash
isort .
```

`mypy`

- Treat these as API or typing clarity issues, not formatting issues.
- Fix the real type shape where possible.
- Avoid adding `type: ignore` unless the reason is specific and defensible.

`pytest`

- Reproduce locally with the smallest failing test file first.
- If the failure is in auth/session/time logic, prefer deterministic tests and fixed timestamps.

`pytest --cov`

- Backend source coverage must stay at or above the current floor.
- The policy also checks critical areas:
  - auth flows
  - session expiry
  - admin permissions
  - settings/CORS
  - billing placeholders

### Flutter

`flutter analyze`

- Usually indicates a real analyzer issue or a stricter lint that needs code cleanup.

`flutter test`

- Prefer fixing setup/test harness issues at the helper level rather than patching one test at a time.

`flutter test --coverage`

- Coverage is currently a baseline gate, not a maturity signal.
- Use the coverage summary to identify neglected repositories, services, and large screens.

## 7. CI Parity

The local workflow is designed to map directly to CI:

- `backend-checks` mirrors the backend quality gates
- `backend-test --coverage` mirrors the backend test-and-coverage job
- `flutter-checks` mirrors analyze + tests
- `flutter-test --coverage` mirrors the Flutter coverage job

If a command passes locally through `tools/dev.py`, it should be close to what CI will run.

## 8. When to Run What

Run the fastest useful command for the scope of the change:

- editing Python only:
  - `python tools/dev.py backend-lint`
- editing backend business logic:
  - `python tools/dev.py backend-checks`
- editing backend auth/session/security/config:
  - `python tools/dev.py backend-test --coverage`
- editing Flutter widgets/state:
  - `python tools/dev.py flutter-checks`
- editing Flutter repositories/routing/startup:
  - `python tools/dev.py flutter-test --coverage`
- editing both stacks:
  - `python tools/dev.py all-checks`

## 9. Recommended Next Step

If the team adopts this workflow consistently, the next useful improvement is not another tool. It is:

- adding a short PR checklist
- using coverage summaries to select the next tests to write
- keeping helper scripts and docs in sync with CI whenever a gate changes

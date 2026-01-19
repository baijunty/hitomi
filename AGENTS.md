# AGENTS.md

## Build, Lint, and Test Commands

The **hitomi** project is a Dart command‑line application.  The following commands are the canonical ways that autonomous agents (or developers) should build, lint, and test the codebase.

| Task | Command | Description |
|------|---------|-------------|
| **Run the application** | `dart run bin/main.dart` | Executes the CLI entry point. |
| **Compile a native executable** | `dart compile exe bin/main.dart -o hitomi` | Produces a self‑contained binary named `hitomi`. |
| **Static analysis / lint** | `dart analyze` | Runs the Dart analyzer using the rules defined in `analysis_options.yaml`. |
| **Run all tests** | `dart test` | Executes every test in the `test/` directory (uses the `test` package). |
| **Run a single test** | `dart test -n "<test‑name>"` | Runs only the test whose description contains `<test‑name>`. Example: `dart test -n "imageResize"`. |
| **Run a specific test file** | `dart test test/dart_tools_test.dart` | Executes only the tests in the given file. |
| **Run tests with verbose output** | `dart test -r expanded` | Shows each test name as it runs. |
| **Run tests with a timeout override** | `dart test --timeout=5m` | Increases the default timeout (useful for long‑running integration tests). |

> **Note**: All commands should be executed from the repository root (`/mnt/soft/code/hitomi`).

---

## Code‑Style Guidelines

The project follows the official Dart style guide with a few project‑specific conventions.  Autonomous agents should enforce these rules when generating or modifying code.

### 1. General Formatting
- Use **`dart format`** (2‑space indentation).  All files should be formatted with `dart format .` before committing.
- End every file with a single newline.
- Limit lines to **80 characters** where possible; longer lines are acceptable for long URLs or strings.

### 2. Imports
- Order imports in three groups separated by a blank line:
  1. **Dart SDK** imports (`dart:io`, `dart:convert`, …)
  2. **Package** imports (`package:...`)
  3. **Relative** imports (`../`, `./`)
- Within each group, sort alphabetically.
- Prefer **single‑line imports**; use `show`/`hide` only when the file needs a small subset.
- Example:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dio/dio.dart';

import '../src/gallery_util.dart';
```

### 3. Naming Conventions
- **Classes / Enums / Type aliases**: `UpperCamelCase`
- **Variables / Functions / Methods**: `lowerCamelCase`
- **Constants**: `lowerCamelCase` (use `const` and name like `defaultTimeout`).  Do **not** use ALL_CAPS.
- **File names**: `snake_case.dart`
- **Test files**: `<feature>_test.dart`
- **Public APIs**: Prefer expressive names; avoid abbreviations unless widely known.

### 4. Types & Null‑Safety
- Declare **explicit types** for public members.  Use `final` for values that never change after initialization.
- Prefer **non‑nullable** types; only use `?` when a value can legitimately be absent.
- When a function may return `null`, document it with a comment and consider returning an `Option<T>`‑like wrapper (e.g., `T?`).
- Use **`required`** named parameters for mandatory arguments.

### 5. Error Handling
- Use **`try` / `catch`** blocks for any I/O, network, or database operation.
- Log errors with the project's `logger` (see `lib/src/task_manager.dart`).  Do **not** swallow exceptions silently.
- When re‑throwing, preserve the original stack trace: `rethrow;`
- For expected error conditions, return a **Result** (e.g., `Either<Error, Value>`) or throw a **custom exception** extending `Exception`.

### 6. Asynchronous Code
- All I/O is `Future`‑based.  Use `async`/`await` consistently; avoid mixing `.then()` with `await` in the same function.
- Prefer **`await`** for readability unless a bulk operation benefits from `Future.wait`.
- Do **not** ignore `Future`s without handling errors; use `_ = someFuture; // ignore` only when truly fire‑and‑forget.

### 7. Data Classes (Freezed)
- Immutable data structures should be defined with **Freezed** (`@freezed`).
- Use the generated `copyWith` for modifications.
- Example:
```dart
@freezed
class UserConfig with _$UserConfig {
  const factory UserConfig({
    required String output,
    @Default('') String logOutput,
  }) = _UserConfig;
}
```

### 8. Logging
- The project uses the `logger` package.  Use the appropriate log level:
  - `logger.d()` – debug information
  - `logger.i()` – informational messages
  - `logger.w()` – recoverable warnings
  - `logger.e()` – errors / exceptions
- Include a **contextual tag** (e.g., the class name) when possible.

### 9. Documentation
- Every public class, method, and top‑level function must have a **dartdoc comment** (`///`).
- Explain **what** the function does, **why** it exists, and **any side effects**.
- Parameter and return types should be documented with `{@macro}` or inline description.

### 10. Testing Guidelines
- Use the **`test`** package.  Each test file should import `package:test/test.dart`.
- Keep tests **fast**; isolate external services (e.g., HTTP) using mocks or the provided `TaskManager` helpers.
- Name tests descriptively; the test description becomes the selector for `dart test -n`.
- For long‑running integration tests, wrap them in a `timeout:` of at least **2 minutes** (as seen in existing tests).

---

## Project‑Specific Rules

- **Cursor / Copilot rules**: No `.cursor` or `.github/copilot‑instructions.md` files are present, so there are no additional constraints.
- **Package versions** are locked in `pubspec.yaml`; do not upgrade without a changelog entry.
- **Database schema** lives in `user.db*`; never commit binary DB files.  Use migrations via `sqlite_helper.dart`.

---

## Quick Reference for Agents

```
# Build
dart run bin/main.dart
dart compile exe bin/main.dart -o hitomi

# Lint / Analyze
dart analyze

# Test
dart test                     # all tests
dart test -n "imageResize"   # single test by name
dart test test/dart_tools_test.dart   # single file

# Formatting
dart format .
```

Agents should always run `dart format .` and `dart analyze` before committing changes.

---

*Generated by an autonomous agent on 2026‑01‑12.*

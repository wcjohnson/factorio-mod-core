# factorio-mod-core

Small and (relatively) independent shared Lua tools for use in Factorio mods. This repository is meant to be consumed as a Git submodule of larger and more featureful mods, in lieu of introducing a full formal dependency.

## Standalone Lua integration tests

The tests in `tests` exercise library modules with mocked Factorio APIs, without
launching Factorio. Run them with your local Lua 5.4 interpreter.

Run all tests from the parent mod repository root:

```powershell
lua54 .\mods\cybersyn2\lib\core\tests\run-tests.lua
```

Or, from this library's root:

```powershell
lua54 .\tests\run-tests.lua
```

Replace `lua54` with your interpreter's command name or executable path. The
runner works from any working directory when invoked by its path and uses the
same interpreter executable for each test. It runs every top-level
`tests\*.lua` file except itself in name order, continues after test failures,
and exits with code 1 if any test file fails (0 if all pass).

### Adding tests

Add a standalone `.lua` test entry point directly in `tests`; the runner discovers
it automatically. Put shared helpers and fixtures in subdirectories so they are
not run as test entry points. Each test runs in a separate Lua process with the
library root as its working directory and its absolute path in `arg[1]`. Use that
path to load modules, mock the Factorio APIs they need, and use assertions or
errors to signal failures.

To run just the polling tests from the library root:

```powershell
lua54 .\tests\train-stop-monitor.lua .
```

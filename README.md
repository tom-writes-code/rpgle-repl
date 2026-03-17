# rpgle-repl

A **REPL** (Read-Evaluate-Print-Loop) for **ILE RPG** on IBM i.

Write small RPG snippets, compile them on the fly, and see the results immediately — no need to create a full program, set breakpoints, or run the debugger.

![Short GIF of REPL evaluating various values](/.github/readme-media/repl-in-action.gif)

## Features

- **Interactive 5250 terminal** — type RPG code, press F11 to compile & run, see results inline.
- **Automatic variable tracking** — changed variables are recorded and displayed next to the line that changed them.
- **Test assertions** — use `replEquals()` to compare expected vs actual values with pass/fail colouring.
- **Snippet save/load** — save snippets by name, browse and reload them later.
- **Batch/CI mode** — run snippets from shell scripts via `REPLWRPR` with configurable verbosity.
- **Fixed & free format support** — write in either format; ruler overlays available for spec checking.
- **Control statement editing** — customise `ctl-opt` per session, per user, or organisation-wide.

## Quick Start

### Install from release

```bash
# SSH into your IBM i, then:
curl -sL https://raw.githubusercontent.com/tom-writes-code/rpgle-repl/main/install.sh | bash
```

Or with options:

```bash
./install.sh --app-lib MYLIB --version v1.0.0
```

### Run interactively

```
RPGLEREPL/REPL
```

### Run from shell (CI)

```bash
./replwrpr.sh --snippet MY_TESTS --verbosity 2
```

## Architecture

rpgle-repl is built as a set of modular ILE service programs:

| Module | Purpose |
|--------|---------|
| **REPL** | Main interactive 5250 terminal (program) |
| **REPLLOAD** | Snippet browser and loader (program) |
| **REPLWRPR** | External/batch wrapper (program) |
| **REPLPRTR** | Batch result printer (program) |
| **REPLCMD** | Command entry point for external callers |
| **REPL_CMPL** | Compiles generated source into modules and programs |
| **REPL_EVAL** | Identifies statement types and generates evaluation code |
| **REPL_GEN** | Transforms pseudo code into compilable SQLRPGLE source |
| **REPL_HLPR** | Runtime helpers called by the generated program to record results |
| **REPL_INS** | Writes individual lines into the generated source member |
| **REPL_PM** | Send and receive escape messages (throw/catch) |
| **REPL_PSEU** | Manages pseudo code CRUD, snippets, results, and control statements |
| **REPL_USR** | User actions: run, debug, show source, spool files, CL commands |
| **REPL_VARS** | Discovers, stores, and retrieves RPG variable metadata |

### Data Flow

```
User types code ──► REPL_PSEU stores to REPLSRC table
                    │
                    ▼
                REPL_GEN generates SQLRPGLE source
                    │   ├── REPL_VARS tracks variable declarations
                    │   ├── REPL_EVAL identifies statement types  
                    │   └── REPL_INS writes lines to source member
                    ▼
                REPL_CMPL compiles (CRTSQLRPGI + CRTPGM)
                    │
                    ▼
                REPL_USR runs the generated program
                    │   └── REPL_HLPR records results to REPLRSLT table
                    ▼
                Results displayed inline next to code
```

### Database Tables

| Table | Purpose |
|-------|---------|
| **REPLSRC** | Stores user-authored pseudo code lines and named snippets |
| **REPLRSLT** | Stores execution results per session and line number |
| **REPLVARS** | Stores variable metadata discovered during code analysis |

### Function Keys (Interactive Mode)

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| F1 | Expand result | F2 | Debug |
| F3 | Exit | F4 | Show ruler |
| F5 | Clear sheet | F6 | Insert line |
| F7 | Spool files | F8 | Job log |
| F9 | Command line | F10 | Compile only |
| F11 | Compile & run | F12 | Run (no compile) |
| F14 | Delete line | F15 | Split line |
| F16 | Control statements | F17 | Show generated source |
| F21 | Save/Load snippet | F24 | Toggle key help |

## Special Functions

### `replPrint(variable)`

Print the current value of any variable:

```rpgle
dcl-s myName varchar(20) inz('world');
replPrint(myName);
// Result: world
```

### `replEquals('label': expected: actual)`

Assert that a value matches an expected result (for testing):

```rpgle
dcl-s result packed(5:0);
result = 2 + 2;
replEquals('two plus two': 4: result);
// Result: TEST-SUCCESS ✓
```

## Building from Source

This project uses **IBM TOBI** for builds. See [TOBI-MIGRATION.md](TOBI-MIGRATION.md) for the full
migration guide from the previous BOB (Better Object Builder) setup.

```bash
# On the IBM i, from the project IFS directory:
makei build
```

For a distributable save file (developer release):

```bash
./package.sh
```

### Project Structure

```
iproj.json           TOBI project configuration
bnd/                 Binding source (.BND files)
cmd/                 CL command definitions (.CMDSRC)
db/                  SQL table definitions (.TABLE)
dsp/                 Display file DDS (.DSPF)
rpgle/               RPG source (.RPGLE, .SQLRPGLE) and includes (.RPGLEINC)
install.sh           One-step installation script (end-user)
package.sh           Build and package a distributable save file (developer)
replwrpr.sh          Shell wrapper for batch execution
TOBI-MIGRATION.md    Full build guide (TOBI setup, flows, troubleshooting)
```

### Source Documentation

All RPG source files include **RPGDoc** annotations (`///` comments with `@file`, `@brief`,
`@param`, `@return`, and `@author` tags). The include files (`.RPGLEINC`) contain the full
public API documentation; the implementation files (`.RPGLE`, `.SQLRPGLE`) contain `@file`
headers describing each module's role.

## Licence

[MIT](LICENSE.txt) — Tom Sharp, 2022.

## Links

- [Wiki](https://github.com/tom-writes-code/rpgle-repl/wiki)
- [Releases](https://github.com/tom-writes-code/rpgle-repl/releases)

e not # Migrating from IBM BOB to IBM TOBI

This document covers the migration of rpgle-repl from **IBM BOB** (Better Object Builder)
to **IBM TOBI** and the IBM i system changes you'll need to make.

## What Changed In This Repo

### Removed
- **All `Rules.mk` files** (root, `bnd/`, `cmd/`, `db/`, `dsp/`, `rpgle/`)
  - BOB used GNU Make with these files to define build targets and dependencies.
  - TOBI auto-discovers source objects from file extensions. No Makefiles needed.

### Added
- **`.ibmi.json` sidecar files** for each *SRVPGM and *PGM
  - `bnd/*.ibmi.json` — one per service program, specifying modules and bound service programs.
  - `rpgle/*.ibmi.json` — one per program, specifying modules, bound service programs, and activation group.
  - These replace the dependency declarations that were in `bnd/Rules.mk` and `rpgle/Rules.mk`.

### Updated
- **`iproj.json`** — `curlib` and `objlib` changed from `REPLBOB` to `RPGLEREPL`.
- **`install.sh`** — `SAVLIB(REPLBOB)` changed to `SAVLIB(RPGLEREPL)` in the RSTOBJ command.

## What You Need To Do On The IBM i

### Step 1: Install TOBI

First, search for the available TOBI package name in your configured repos:

```bash
yum search tobi
```

Install whichever package name is returned (e.g. `ibm-tobi`, `tobi`, `ibm-i-tobi`):

```bash
yum install <package-name>
```

If `yum search tobi` returns nothing, TOBI may not yet be in your configured repos. In that
case check the IBM open-source Bootstrap to ensure all IBM repos are registered, then retry:

```bash
/QOpenSys/pkgs/bin/bootstrap.sh
yum search tobi
```

If you previously had BOB installed, you can remove it (or leave it — they don't conflict):

```bash
yum remove ibm-bob
```

Verify TOBI is installed:

```bash
tobi --version
```

### Step 2: Create / Rename the Target Library

The build library changed from `REPLBOB` to `RPGLEREPL`. You have two options:

**Option A — Create a fresh library (recommended):**
```
CRTLIB LIB(RPGLEREPL) TEXT('REPL tool for ILE RPG')
```

**Option B — Rename the existing library:**
```
RNMOBJ OBJ(REPLBOB) OBJTYPE(*LIB) NEWOBJ(RPGLEREPL)
```

### Step 3: Build With TOBI

From the IFS project directory (wherever you cloned the repo), run:

```bash
tobi build
```

TOBI reads `iproj.json` for the target library, auto-discovers your source files by extension,
and reads the `.ibmi.json` sidecar files for build parameters (bound service programs, activation
group, etc.).

That's it. No `makei` call, no Makefile targets. TOBI handles the build order and dependencies
automatically.

### Step 4: Verify the Build

Check that all objects were created:

```
WRKOBJ OBJ(RPGLEREPL/*ALL)
```

You should see:
- 9 service programs: `REPL_CMPL`, `REPL_EVAL`, `REPL_GEN`, `REPL_HLPR`, `REPL_INS`, `REPL_PM`, `REPL_PSEU`, `REPL_USR`, `REPL_VARS`
- 4 programs: `REPL`, `REPLLOAD`, `REPLWRPR`, `REPLPRTR`
- 3 commands: `REPL`, `REPLWRPR`, `REPLPRTR`
- 3 SQL tables: `REPLRSLT`, `REPLSRC`, `REPLVARS`
- 2 display files: `REPLFM`, `REPLLOADFM`

### Step 5: Update Any CI/CD Scripts

If you had any automation calling `makei` or referencing `REPLBOB`, update them:

| Before (BOB)            | After (TOBI)              |
|-------------------------|---------------------------|
| `makei build`           | `tobi build`              |
| `REPLBOB` library       | `RPGLEREPL` library       |
| `Rules.mk` dependencies | `.ibmi.json` sidecar      |

## How TOBI Discovers Objects

TOBI uses file extensions to determine object types:

| Extension     | Object Type          |
|---------------|----------------------|
| `.RPGLE`      | *MODULE (RPGLE)      |
| `.SQLRPGLE`   | *MODULE (SQLRPGLE)   |
| `.BND`        | *SRVPGM (exports)    |
| `.CMDSRC`     | *CMD                 |
| `.TABLE`      | SQL table (via RUNSQLSTM) |
| `.DSPF`       | *FILE (display file) |

When a `.ibmi.json` file sits next to a source file with the same base name, TOBI reads it
for additional build parameters (object type overrides, modules, bound service programs,
activation group, text description, etc.).

## Troubleshooting

**"TOBI can't find my source"**
- Make sure your file extensions match TOBI's expectations (see table above).
- Check that `iproj.json` exists in the project root.

**"Objects are building into the wrong library"**
- Check `objlib` in `iproj.json` — it should be `RPGLEREPL`.

**"Service program binding fails"**
- Build order matters. TOBI resolves this automatically, but if you see binding errors,
  check the `.ibmi.json` files in `bnd/` to make sure the `bndSrvPgm` arrays are correct.

**"I still have the old REPLBOB library"**
- You can delete it: `DLTLIB LIB(REPLBOB)`
- Or keep it around as a backup until you're satisfied TOBI builds work.

# Building rpgle-repl with TOBI (makei)

This document covers how to build rpgle-repl from source using
[TOBI](https://github.com/IBM/ibmi-tobi/) (The Object Builder for IBM i).

There are two build flows:

1. **User build** — compile from source into a library: `makei build`
2. **Developer release** — compile + produce a distributable save file: `./package.sh`

## Prerequisites

### Install TOBI

```bash
yum install tobi
makei --version
```

> The `tobi` RPM package provides the `makei` CLI — there is no `tobi` command.

If `yum install tobi` says "No package tobi available", ensure IBM repos are registered:

```bash
/QOpenSys/pkgs/bin/bootstrap.sh
yum search tobi
yum install <package-name>
```

### Create the target library

```
CRTLIB LIB(RPGLEREPL) TEXT('REPL tool for ILE RPG')
```

Or, if renaming the old BOB library:

```
RNMOBJ OBJ(REPLBOB) OBJTYPE(*LIB) NEWOBJ(RPGLEREPL)
```

## Flow 1: User Build (compile from source)

```bash
cd /path/to/rpgle-repl
makei build
```

`makei` reads `iproj.json` for the target library, walks the `Rules.mk` files in each
subdirectory for dependency and compile-override information, and builds everything in
the correct order.

### Verify

```
WRKOBJ OBJ(RPGLEREPL/*ALL)
```

You should see:
- 9 service programs: `REPL_CMPL`, `REPL_EVAL`, `REPL_GEN`, `REPL_HLPR`, `REPL_INS`, `REPL_PM`, `REPL_PSEU`, `REPL_USR`, `REPL_VARS`
- 4 programs: `REPL`, `REPLLOAD`, `REPLWRPR`, `REPLPRTR`
- 3 commands: `REPL`, `REPLWRPR`, `REPLPRTR`
- 3 SQL tables: `REPLRSLT`, `REPLSRC`, `REPLVARS`
- 2 display files: `REPLFM`, `REPLLOADFM`

## Flow 2: Developer Release (compile + save file)

```bash
cd /path/to/rpgle-repl
chmod +x package.sh
./package.sh
```

This runs `makei build`, then creates a distributable save file `RPGLEREPL/RPGLEREPL`
with public authority granted, ownership set to QPGMR, and all objects saved
(excluding modules, save files, and EVFEVENT event files).

To target a different library:

```bash
./package.sh MYLIB
```

## What Changed From BOB

| Before (BOB)                        | After (TOBI)                                   |
|-------------------------------------|-------------------------------------------------|
| `REPLBOB` library                   | `RPGLEREPL` library                             |
| `$(d)/` prefix on source in Rules.mk| No prefix needed (TOBI 2.4+)                   |
| Object type lists (`SRVPGMs :=`)    | Auto-discovered (TOBI 2.4+)                    |
| `package` make target in root Rules.mk | Separate `package.sh` script                |
| TEXT as comments (`# ...TEXT=...`)   | `private TEXT :=` compile override in Rules.mk  |

## How TOBI Works

TOBI uses GNU Make under the covers. Each directory has a `Rules.mk` that declares:

- **Dependency lines**: what each object is built from and what it depends on
- **Compile overrides**: `private TEXT :=`, `private ACTGRP :=`, etc.
- **Custom recipes**: for non-standard build steps (none currently needed)

Object types are inferred from file extensions:

| Extension     | Object Type               |
|---------------|---------------------------|
| `.RPGLE`      | \*MODULE (RPGLE)          |
| `.SQLRPGLE`   | \*MODULE (SQLRPGLE)       |
| `.BND`        | \*SRVPGM (binder source)  |
| `.CMDSRC`     | \*CMD                     |
| `.TABLE`      | SQL table (RUNSQLSTM)     |
| `.DSPF`       | \*FILE (display file)     |

`.ibmi.json` files (optional, per-directory) can override `objlib` and `tgtCcsid` only.
All other build metadata (dependencies, TEXT, ACTGRP, etc.) goes in `Rules.mk`.

Docs: https://ibm.github.io/ibmi-tobi/

## Troubleshooting

**`tobi: command not found`**
- The CLI is `makei`, not `tobi`. Run `which makei` and `makei --version`.

**`Warning: Target 'PACKAGE' is not supported`**
- Custom make targets like `package` are not supported by `makei build`.
  Packaging is now handled by `./package.sh` instead.

**`No rule to make target '.Rules.mk.build'`**
- A `Rules.mk` file is missing. Every source directory needs one.

**Objects building into wrong library**
- Check `objlib` in `iproj.json` — it should be `RPGLEREPL`.

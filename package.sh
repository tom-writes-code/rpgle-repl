#!/usr/bin/env bash
# package.sh — Build all objects and create a distributable save file.
#
# Usage:
#   ./package.sh [LIBRARY]
#
# LIBRARY defaults to the objlib in iproj.json (RPGLEREPL).
# Run this from the project root on IBM i (PASE shell).

set -e

LIB="${1:-RPGLEREPL}"

echo "=== Building project into ${LIB}..."
makei build

echo "=== Removing old save file (if any)..."
system "DLTOBJ OBJ(${LIB}/RPGLEREPL) OBJTYPE(*FILE)" 2>/dev/null || true

echo "=== Creating save file ${LIB}/RPGLEREPL..."
system "CRTSAVF FILE(${LIB}/RPGLEREPL)"

echo "=== Granting *PUBLIC *ALL authority..."
system "GRTOBJAUT OBJ(${LIB}/*ALL) USER(*PUBLIC) OBJTYPE(*ALL) AUT(*ALL)"

echo "=== Changing library ownership to QPGMR..."
system "CHGOWN OBJ('/QSYS.LIB/${LIB}.LIB') NEWOWN(QPGMR)"

echo "=== Saving objects to save file..."
system "SAVOBJ OBJ(*ALL) LIB(${LIB}) DEV(*SAVF) SAVF(${LIB}/RPGLEREPL) CLEAR(*REPLACE) DTACPR(*YES) SELECT((*OMIT *ALL *FILE SAVF) (*OMIT *ALL *MODULE) (*OMIT EVFEVENT *FILE))"

echo "=== Done. Distributable save file: ${LIB}/RPGLEREPL"

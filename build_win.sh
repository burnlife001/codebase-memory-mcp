#!/usr/bin/env bash
set -e
cd /e/__work/BaseTools/codebase-memory-mcp
make -f Makefile.cbm cbm -j"$(nproc)" CC=gcc CXX=g++ CFLAGS_EXTRA='-Wno-error' > /tmp/cbm_build.log 2>&1
rc=$?
tail -60 /tmp/cbm_build.log
[ $rc -eq 0 ] || exit $rc
echo "=== BUILD DONE ==="
ls -la build/c/codebase-memory-mcp* build/c/*.exe 2>/dev/null

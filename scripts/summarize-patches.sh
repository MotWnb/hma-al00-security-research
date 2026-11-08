#!/bin/bash
for f in /opt/lab/logs/*.patch; do
  echo "=== $(basename "$f")  ($(grep -cE '^[+-][^+-]' "$f") changed lines)"
  grep -E '^(---|\+\+\+|@@)' "$f" | head -6
  echo
done

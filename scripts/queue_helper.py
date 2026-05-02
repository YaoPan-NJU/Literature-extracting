#!/usr/bin/env python3
"""Atomic queue and manifest operations for multi-worker extraction.
Uses fcntl.flock for cross-platform (including macOS) file locking."""
import fcntl
import sys
import os
import json

def queue_pop(queue_file):
    """Atomically pop the first line from the queue file. Returns empty string if queue is empty."""
    lock_file = queue_file + ".lock"
    with open(lock_file, 'w') as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            if not os.path.exists(queue_file) or os.path.getsize(queue_file) == 0:
                return ""
            with open(queue_file, 'r') as qf:
                lines = qf.readlines()
            if not lines:
                return ""
            first = lines[0].rstrip('\n')
            with open(queue_file, 'w') as qf:
                qf.writelines(lines[1:])
            return first
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)

def queue_remaining(queue_file):
    """Return number of items remaining in queue."""
    if not os.path.exists(queue_file):
        return 0
    with open(queue_file, 'r') as f:
        return sum(1 for line in f if line.strip())

def manifest_append(tsv_path, columns):
    """Atomically append a TSV row."""
    lock_file = tsv_path + ".lock"
    with open(lock_file, 'w') as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            with open(tsv_path, 'a') as f:
                f.write('\t'.join(str(c) for c in columns) + '\n')
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'pop':
        print(queue_pop(sys.argv[2]))
    elif cmd == 'remaining':
        print(queue_remaining(sys.argv[2]))
    elif cmd == 'append':
        # append <tsv_path> <col1> <col2> ...
        manifest_append(sys.argv[2], sys.argv[3:])
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

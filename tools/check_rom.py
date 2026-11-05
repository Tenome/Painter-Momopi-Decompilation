#!/usr/bin/env python3
"""Compare a built ROM with the expected SHA-1 and, when the original is present, report the first differing byte."""
import hashlib, os, sys

built = open(sys.argv[1], "rb").read()
want = sys.argv[2]
got = hashlib.sha1(built).hexdigest()
if got == want:
    print(f"OK: {sys.argv[1]} is byte-identical to the original ({got})")
    sys.exit(0)
print(f"MISMATCH: {got} != {want}")
orig = os.path.join(os.path.dirname(__file__), "..", "orig", "painter_momopie.gb")
if os.path.exists(orig):
    o = open(orig, "rb").read()
    d = [i for i in range(min(len(o), len(built))) if o[i] != built[i]]
    print(f"{len(d)} differing bytes; first at ${d[0]:05x}" if d else f"sizes differ: {len(built)} vs {len(o)}")
sys.exit(1)

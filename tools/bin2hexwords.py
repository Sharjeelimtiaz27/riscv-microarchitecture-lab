#!/usr/bin/env python3
# tools/bin2hexwords.py
# Usage: python3 bin2hexwords.py input.bin output.hex

import sys
if len(sys.argv) != 3:
    print("Usage: bin2hexwords.py input.bin output.hex")
    sys.exit(1)

inp = sys.argv[1]
out = sys.argv[2]

with open(inp, "rb") as f:
    data = f.read()

# pad to word size
while len(data) % 4 != 0:
    data += b'\x00'

words = [data[i:i+4] for i in range(0, len(data), 4)]

with open(out, "w") as f:
    for w in words:
        # little-endian -> convert to hex word in natural visual order
        val = int.from_bytes(w, byteorder='little', signed=False)
        f.write("{:08x}\n".format(val))
print(f"Wrote {len(words)} words to {out}")
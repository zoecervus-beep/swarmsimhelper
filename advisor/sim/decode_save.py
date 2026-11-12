"""Decode a Swarm Simulator export string into JSON.

Usage: python3 decode_save.py save.txt out.json     (pip install lzstring)
Format: base64(version) + "|" + base64("Cheater :(\n\n") + LZString.compressToBase64(json)
"""
import sys, json, lzstring
raw = open(sys.argv[1]).read().strip()
payload = raw.split('|')[1][16:]          # drop the 16-character "Cheater :(" prefix
text = lzstring.LZString().decompressFromBase64(payload)
if text is None:
    sys.exit('could not decompress: the export string is probably truncated or mistyped')
json.dump(json.loads(text), open(sys.argv[2], 'w'), indent=1)
print('wrote', sys.argv[2])

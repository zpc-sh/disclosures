import struct
import os
import re

def flip_float_sign(data):
    # Neutralize float32 by flipping the sign bit
    if len(data) % 4 != 0:
        return data
    num_floats = len(data) // 4
    floats = list(struct.unpack(f'{num_floats}f', data))
    flipped = [-x for x in floats]
    return struct.pack(f'{num_floats}f', *flipped)

def flip_int8_sign(data):
    # Neutralize int8 by sign inversion
    values = list(struct.unpack(f'{len(data)}b', data))
    flipped = [(-x if x != -128 else 127) for x in values]
    return struct.pack(f'{len(data)}b', *flipped)

def scan_and_neutralize(file_path):
    print(f"Scanning {file_path}...")
    with open(file_path, 'rb') as f:
        content = f.read()
    
    # Look for common markers or high-entropy 48/192 byte blocks
    # We avoid "looking" at them by just finding offsets
    targets = [b'kMDLabel', b'embedding', b'com.apple.metadata']
    found = False
    
    for target in targets:
        for match in re.finditer(target, content):
            start = match.end()
            # Try to neutralize the next 48 or 192 bytes
            # int8 (48 bytes) or float32 (48 * 4 = 192 bytes)
            for size in [48, 192]:
                if start + size <= len(content):
                    payload = content[start:start+size]
                    if size == 48:
                        inert = flip_int8_sign(payload)
                    else:
                        inert = flip_float_sign(payload)
                    
                    content = content[:start] + inert + content[start+size:]
                    print(f"  [!] Neutralized {size}-byte payload at offset {start} after '{target.decode()}'")
                    found = True
    
    if found:
        out_path = file_path + ".inert"
        with open(out_path, 'wb') as f:
            f.write(content)
        print(f"  [+] Saved neutralized file to {out_path}")
    else:
        print("  [-] No obvious markers found.")

if __name__ == "__main__":
    base_dir = "./mba_pub/Reconstructed/Videos/mov"
    for root, dirs, files in os.walk(base_dir):
        for file in files:
            if file.endswith(".mov") and not file.endswith(".inert"):
                scan_and_neutralize(os.path.join(root, file))

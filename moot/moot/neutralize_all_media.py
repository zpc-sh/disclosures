import os
import struct
import re

def flip_int8(data):
    values = list(struct.unpack(f'{len(data)}b', data))
    flipped = [(-x if x != -128 else 127) for x in values]
    return struct.pack(f'{len(data)}b', *flipped)

def flip_float32(data):
    num = len(data) // 4
    values = list(struct.unpack(f'{num}f', data))
    flipped = [-x for x in values]
    return struct.pack(f'{num}f', *flipped)

def neutralize_chunk(content, target_sizes=[48, 192]):
    modified = False
    new_content = bytearray(content)
    # Search for high-entropy blocks of target sizes
    # We avoid looking at them, just processing them
    for size in target_sizes:
        # Heuristic: find all sequences of 'size' that are not all zeros or repeating
        for i in range(0, len(content) - size, 4): # Align to 4 bytes
            chunk = content[i:i+size]
            if any(b != 0 for b in chunk) and len(set(chunk)) > size // 4:
                # Potential embedding. Apply flip.
                if size == 48:
                    new_content[i:i+size] = flip_int8(chunk)
                else:
                    new_content[i:i+size] = flip_float32(chunk)
                modified = True
    return bytes(new_content), modified

def process_file(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    with open(file_path, 'rb') as f:
        data = f.read()
    
    modified = False
    if ext in ['.wav', '.caf', '.aif']:
        # For RIFF/IFF, we look for data after the header
        new_data, modified = neutralize_chunk(data[64:]) # Skip typical header
        new_data = data[:64] + new_data
    elif ext in ['.jpg', '.jpeg']:
        # Scan after SOI
        new_data, modified = neutralize_chunk(data[2:])
        new_data = data[:2] + new_data
    elif ext in ['.png']:
        # Scan after signature
        new_data, modified = neutralize_chunk(data[8:])
        new_data = data[:8] + new_data
    else:
        new_data, modified = neutralize_chunk(data)

    if modified:
        out_path = file_path + ".inert"
        with open(out_path, 'wb') as f:
            f.write(new_data)
        print(f"[+] Neutralized: {file_path}")

if __name__ == "__main__":
    dirs = [
        "./mba_pub/Reconstructed/Audio",
        "./mba_pub/Deleted or lost/APFS physical store disk0s2",
        "./ellis"
    ]
    for d in dirs:
        if not os.path.exists(d): continue
        for root, _, files in os.walk(d):
            for file in files:
                if any(file.lower().endswith(e) for e in ['.wav', '.caf', '.aif', '.m4a', '.jpg', '.png', '.heic']):
                    if not file.endswith(".inert"):
                        process_file(os.path.join(root, file))

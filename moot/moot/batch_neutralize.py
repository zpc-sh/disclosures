import os
import struct

def flip_int8(data):
    values = list(struct.unpack(f'{len(data)}b', data))
    flipped = [(-x if x != -128 else 127) for x in values]
    return struct.pack(f'{len(data)}b', *flipped)

def flip_float32(data):
    num = len(data) // 4
    values = list(struct.unpack(f'{num}f', data))
    flipped = [-x for x in values]
    return struct.pack(f'{num}f', *flipped)

def neutralize_file(file_path):
    with open(file_path, 'rb') as f:
        data = f.read()
    new_data = bytearray(data)
    modified = False
    for size in [48, 192]:
        for i in range(0, len(data) - size, 4):
            chunk = data[i:i+size]
            if any(b != 0 for b in chunk) and len(set(chunk)) > size // 4:
                if size == 48: new_data[i:i+size] = flip_int8(chunk)
                else: new_data[i:i+size] = flip_float32(chunk)
                modified = True
    if modified:
        out_path = file_path + ".inert"
        with open(out_path, 'wb') as f: f.write(new_data)
        print(f"[+] Neutralized: {file_path}")
    else: print(f"[-] No embeddings: {file_path}")

if __name__ == "__main__":
    targets = [
        "./mba_pub/Reconstructed/Audio/wav/file000000.wav",
        "./mba_pub/Reconstructed/Audio/wav/file000001.wav",
        "./mba_pub/Reconstructed/Audio/wav/file000002.wav",
        "./mba_pub/Reconstructed/Audio/wav/file000003.wav"
    ]
    for t in targets:
        if os.path.exists(t): neutralize_file(t)

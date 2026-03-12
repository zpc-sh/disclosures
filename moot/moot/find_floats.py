import struct
import sys
import math

def is_plausible_float(f):
    if math.isnan(f) or math.isinf(f):
        return False
    if abs(f) > 1e10 or (f != 0 and abs(f) < 1e-10):
        return False
    return True

def scan_file(file_path):
    print(f"Scanning {file_path}...")
    with open(file_path, 'rb') as f:
        data = f.read()
    
    # Scan for sequences of 48 float32s
    cluster_size = 48
    byte_cluster_size = cluster_size * 4
    
    found_count = 0
    for i in range(0, len(data) - byte_cluster_size, 4):
        chunk = data[i:i+byte_cluster_size]
        try:
            floats = struct.unpack(f'{cluster_size}f', chunk)
            if all(is_plausible_float(x) for x in floats) and any(x != 0 for x in floats):
                # Check for high entropy/variance to distinguish from regular data
                mean = sum(floats) / len(floats)
                variance = sum((x - mean) ** 2 for x in floats) / len(floats)
                if variance > 0.001:
                    print(f"  [!] Potential float32 embedding cluster (dim 48) at offset {i}, variance: {variance:.4f}")
                    found_count += 1
                    if found_count > 10:
                        print("  [...] Too many clusters, stopping.")
                        break
        except:
            continue

if __name__ == "__main__":
    scan_file("./mba_pub/Reconstructed/Videos/mov/HEVC 3840x2160 02m00s_000020.mov")

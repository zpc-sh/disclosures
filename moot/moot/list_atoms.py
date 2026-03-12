import struct
import sys

def list_atoms(file_path):
    print(f"Atoms in {file_path}:")
    with open(file_path, 'rb') as f:
        while True:
            header = f.read(8)
            if len(header) < 8:
                break
            size, name = struct.unpack('>I4s', header)
            print(f"  {name.decode(errors='ignore')} - {size} bytes at {f.tell()-8}")
            if size == 1: # Extended size
                size_ext = struct.unpack('>Q', f.read(8))[0]
                f.seek(size_ext - 16, 1)
            elif size > 8:
                f.seek(size - 8, 1)
            else:
                break

if __name__ == "__main__":
    list_atoms("./mba_pub/Reconstructed/Videos/mov/HEVC 3840x2160 02m00s_000020.mov")

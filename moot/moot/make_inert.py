import struct
import os
import glob

def make_inert(target_dir):
    files = glob.glob(os.path.join(target_dir, "*.bin"))
    for file_path in files:
        if file_path.endswith(".inert"):
            continue
        with open(file_path, 'rb') as f:
            data = f.read()
        
        if len(data) == 48:
            # Handle as int8 quantized vectors per GEMINI_ANALYSIS.md
            values = list(struct.unpack('48b', data))
            flipped = []
            for x in values:
                if x == -128:
                    flipped.append(127) # Cap to avoid overflow
                else:
                    flipped.append(-x)
            inert_data = struct.pack('48b', *flipped)
            out_path = file_path + ".inert"
            with open(out_path, 'wb') as f:
                f.write(inert_data)
            print(f"Made inert (int8 sign flip): {out_path}")
        elif len(data) % 4 == 0 and len(data) > 0:
            # Fallback for 32-bit floats
            num_floats = len(data) // 4
            fmt = f'{num_floats}f'
            floats = list(struct.unpack(fmt, data))
            flipped = [-x for x in floats]
            inert_data = struct.pack(fmt, *flipped)
            out_path = file_path + ".inert"
            with open(out_path, 'wb') as f:
                f.write(inert_data)
            print(f"Made inert (32-bit float sign flip): {out_path}")
        else:
            print(f"Skipped {file_path}, size {len(data)} not handled.")

if __name__ == "__main__":
    make_inert("ellis/quarantine_kmdlabel")
    make_inert("ellis/more_bad")

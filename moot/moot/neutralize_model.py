import struct
import os

def flip_float32_file(file_path):
    print(f"Neutralizing model weights: {file_path}")
    with open(file_path, 'rb') as f:
        data = f.read()
    
    # Weights are typically float32 (4 bytes)
    num = len(data) // 4
    if num == 0:
        print("  [-] File too small.")
        return
        
    values = list(struct.unpack(f'{num}f', data[:num*4]))
    flipped = [-x for x in values]
    new_data = struct.pack(f'{num}f', *flipped) + data[num*4:] # Keep trailing bytes
    
    out_path = file_path + ".inert"
    with open(out_path, 'wb') as f:
        f.write(new_data)
    print(f"  [+] Saved neutralized weights to {out_path}")

if __name__ == "__main__":
    target = "KEYCHAIN/ai_takeover/20240516_control_minus_topic_48d/fy/model.mlmodelc/weights/weight.bin"
    if os.path.exists(target):
        flip_float32_file(target)
    
    # Also target the article encoding weights
    target2 = "KEYCHAIN/ai_takeover/20240516_control_minus_topic_48d/hist_article_encoding/enc.mlmodelc/weights/weight.bin"
    # Need to check if it exists first

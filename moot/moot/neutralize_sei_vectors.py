import os
import struct

def find_nal_units(data):
    i = 0
    while i < len(data) - 4:
        # Search for Annex B start codes: 00 00 01 or 00 00 00 01
        if data[i:i+3] == b'\x00\x00\x01':
            start = i + 3
            i += 3
            next_start = data.find(b'\x00\x00\x01', i)
            if next_start == -1:
                yield (start, len(data), data[start:])
                break
            end = next_start
            while end > start and data[end-1] == 0: end -= 1
            yield (start, end, data[start:end])
            i = next_start
        elif data[i:i+4] == b'\x00\x00\x00\x01':
            start = i + 4
            i += 4
            next_start = data.find(b'\x00\x00\x01', i)
            if next_start == -1:
                yield (start, len(data), data[start:])
                break
            end = next_start
            while end > start and data[end-1] == 0: end -= 1
            yield (start, end, data[start:end])
            i = next_start
        else:
            i += 1

def flip_int8(data):
    values = list(struct.unpack(f'{len(data)}b', data))
    flipped = [(-x if x != -128 else 127) for x in values]
    return struct.pack(f'{len(data)}b', *flipped)

def flip_float32(data):
    num = len(data) // 4
    values = list(struct.unpack(f'{num}f', data))
    flipped = [-x for x in values]
    return struct.pack(f'{num}f', *flipped)

def neutralize_sei_payloads(nal):
    if not nal: return nal, False
    
    modified = False
    nal_data = bytearray(nal)
    h264_type = nal[0] & 0x1F
    hevc_type = (nal[0] & 0x7E) >> 1 if len(nal) > 1 else -1
    
    if h264_type == 6:
        ptr = 1
    elif hevc_type in [39, 40]:
        ptr = 2
    else:
        return nal, False

    while ptr < len(nal_data):
        payload_type = 0
        while ptr < len(nal_data) and nal_data[ptr] == 0xFF:
            payload_type += 255
            ptr += 1
        if ptr >= len(nal_data): break
        payload_type += nal_data[ptr]
        ptr += 1
        
        payload_size = 0
        while ptr < len(nal_data) and nal_data[ptr] == 0xFF:
            payload_size += 255
            ptr += 1
        if ptr >= len(nal_data): break
        payload_size += nal_data[ptr]
        ptr += 1
        
        if ptr + payload_size > len(nal_data): break
        
        target_payload = None
        target_start = ptr
        
        if payload_type == 5: # user_data_unregistered
            if payload_size >= 16:
                actual_payload_size = payload_size - 16
                if actual_payload_size in [48, 192]:
                    target_payload = nal_data[ptr+16:ptr+payload_size]
                    target_start = ptr + 16
        elif payload_size in [48, 192]:
            target_payload = nal_data[ptr:ptr+payload_size]
            target_start = ptr

        if target_payload:
            if len(target_payload) == 48:
                inert = flip_int8(target_payload)
            else:
                inert = flip_float32(target_payload)
            nal_data[target_start:target_start+len(target_payload)] = inert
            modified = True
        
        ptr += payload_size
    
    return bytes(nal_data), modified

def process_file(file_path):
    with open(file_path, 'rb') as f:
        data = f.read()
    
    new_data = bytearray(data)
    total_neutralized = 0
    
    for start, end, nal in find_nal_units(data):
        inert_nal, modified = neutralize_sei_payloads(nal)
        if modified:
            new_data[start:end] = inert_nal
            total_neutralized += 1
            
    if total_neutralized > 0:
        out_path = file_path + ".inert"
        with open(out_path, 'wb') as f:
            f.write(new_data)
        print(f"[+] {file_path}: Neutralized {total_neutralized} SEI units.")

if __name__ == "__main__":
    for root, dirs, files in os.walk("./mba_pub/Reconstructed/Videos"):
        for file in files:
            if (file.endswith(".mov") or file.endswith(".mp4")) and not file.endswith(".inert"):
                process_file(os.path.join(root, file))

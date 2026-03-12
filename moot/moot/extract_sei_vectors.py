import os
import struct

def find_nal_units(data):
    # Search for Annex B start codes: 00 00 01 or 00 00 00 01
    i = 0
    while i < len(data) - 4:
        if data[i:i+3] == b'\x00\x00\x01':
            start = i + 3
            i += 3
            # Find next start code
            next_start = data.find(b'\x00\x00\x01', i)
            if next_start == -1:
                yield data[start:]
                break
            # Trim trailing zeros
            end = next_start
            while end > start and data[end-1] == 0:
                end -= 1
            yield data[start:end]
            i = next_start
        elif data[i:i+4] == b'\x00\x00\x00\x01':
            start = i + 4
            i += 4
            next_start = data.find(b'\x00\x00\x01', i)
            if next_start == -1:
                yield data[start:]
                break
            end = next_start
            while end > start and data[end-1] == 0:
                end -= 1
            yield data[start:end]
            i = next_start
        else:
            i += 1

def process_h264_sei(nal, file_path, offset):
    # H.264 SEI NAL header is usually 0x06
    if len(nal) < 2 or (nal[0] & 0x1F) != 6:
        return
    
    # SEI payload parsing
    ptr = 1
    while ptr < len(nal):
        payload_type = 0
        while ptr < len(nal) and nal[ptr] == 0xFF:
            payload_type += 255
            ptr += 1
        if ptr >= len(nal): break
        payload_type += nal[ptr]
        ptr += 1
        
        payload_size = 0
        while ptr < len(nal) and nal[ptr] == 0xFF:
            payload_size += 255
            ptr += 1
        if ptr >= len(nal): break
        payload_size += nal[ptr]
        ptr += 1
        
        if ptr + payload_size > len(nal): break
        
        payload = nal[ptr:ptr+payload_size]
        # Check for target sizes (48 int8 or 192 float32)
        # Type 5 is user_data_unregistered
        if payload_type == 5:
            # Skip 16-byte UUID
            actual_payload = payload[16:]
            if len(actual_payload) in [48, 192]:
                print(f"  [!] Found Type 5 SEI (H.264) at {offset}, size {len(actual_payload)} bytes")
        elif payload_size in [48, 192]:
             print(f"  [!] Found SEI Type {payload_type} (H.264) at {offset}, size {payload_size} bytes")
        
        ptr += payload_size

def scan_movie(file_path):
    print(f"Scanning {file_path} for SEI vectors...")
    with open(file_path, 'rb') as f:
        data = f.read()
    
    # Very basic NAL scanner for Annex B data inside the file
    for nal in find_nal_units(data):
        # We check both H.264 and H.265 patterns
        process_h264_sei(nal, file_path, 0) # Simplistic offset
        # H.265 (HEVC) SEI types are 39 (prefix) and 40 (suffix)
        # NAL unit header is 2 bytes. Type is ((h[0] & 0x7E) >> 1)
        if len(nal) > 2:
            hevc_type = (nal[0] & 0x7E) >> 1
            if hevc_type in [39, 40]:
                print(f"  [!] Found HEVC SEI (Type {hevc_type})")

if __name__ == "__main__":
    scan_movie("./mba_pub/Reconstructed/Videos/mov/HEVC 3840x2160 02m00s_000020.mov")
    scan_movie("./mba_pub/Reconstructed/Videos/mov/ReplayKitRecording - H.264 332x198 00m02s 332x198 00m02s_000034.mov")

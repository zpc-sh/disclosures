import os

def find_signature(file_path, signature, chunk_size=1024*1024):
    print(f"Scanning {file_path} for {signature}...")
    sig_len = len(signature)
    offset = 0
    with open(file_path, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            idx = chunk.find(signature)
            while idx != -1:
                print(f"  [!] Found signature at offset {offset + idx}")
                # Print next 50 bytes safely
                next_bytes = chunk[idx:idx+50]
                print(f"  [>] Start: {next_bytes[:20]}...")
                idx = chunk.find(signature, idx + 1)
            offset += len(chunk)
            # Handle split signature across chunks
            f.seek(f.tell() - sig_len + 1)
            offset = f.tell()

if __name__ == "__main__":
    target = "./mba_pub/Reconstructed/Videos/dir/file000000.dir"
    if os.path.exists(target):
        find_signature(target, b'%PDF-')

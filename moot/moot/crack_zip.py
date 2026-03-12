import zipfile
import sys

def crack():
    zip_path = "mba_pub/Reconstructed/Archives/zip/86 files_000000.zip"
    wordlist_path = "mba_pub/Reconstructed/Documents/cs/file000000.cs"
    
    try:
        zf = zipfile.ZipFile(zip_path)
        with open(wordlist_path, 'r', encoding='utf-8', errors='ignore') as f:
            # The file is a mix of tags and word lists. Let's extract clean tokens.
            content = f.read()
            # Split by common delimiters
            words = set()
            import re
            tokens = re.split(r'[ \n\r\t\<\>/\(\)\"\'\=\,\.\;]+', content)
            for t in tokens:
                if t: words.add(t)
        
        print(f"Attempting crack with {len(words)} unique tokens...")
        for word in words:
            try:
                zf.extractall(path="KEYCHAIN/unzipped_86", pwd=word.encode('utf-8'))
                print(f"SUCCESS! Password is: {word}")
                return
            except:
                continue
        print("Failed to find password in token set.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    crack()

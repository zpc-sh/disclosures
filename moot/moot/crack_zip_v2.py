import zipfile
import re

def crack():
    zip_path = "mba_pub/Reconstructed/Archives/zip/86 files_000000.zip"
    cs_path = "mba_pub/Reconstructed/Documents/cs/file000000.cs"
    rtf_path = "mba_pub/Reconstructed/Documents/rtf/file000000.rtf"
    vcf_path = "mba_bk3/Personal data/Contacts/Lọ̀́̉̃c Tụ̀́̉̃c.vcf"
    
    words = set()
    
    # 1. CS wordlist
    try:
        with open(cs_path, 'r', encoding='utf-8', errors='ignore') as f:
            tokens = re.split(r'[ \n\r\t\<\>/\(\)\"\'\=\,\.\;]+', f.read())
            words.update([t for t in tokens if t])
    except: pass

    # 2. RTF levels
    try:
        with open(rtf_path, 'r') as f:
            content = f.read()
            # Extract plain text words from RTF
            words.update(["Ebene", "Eins", "Zwei", "Drei"])
    except: pass

    # 3. VCF unusual fields
    try:
        with open(vcf_path, 'r') as f:
            words.update(["Tụ̀́̉̃c", "Lọ̀́̉̃c", "Cicada"])
    except: pass

    # 4. Common combinations or derived strings
    words.update(["apple", "Apple", "iCloud", "Siri", "Spotlight", "Matrix", "matrix"])

    try:
        zf = zipfile.ZipFile(zip_path)
        print(f"Attempting crack with {len(words)} candidates...")
        for word in words:
            # Try both utf-8 and latin-1 encodings for the password
            for enc in ['utf-8', 'cp437']:
                try:
                    zf.extractall(path="KEYCHAIN/unzipped_86", pwd=word.encode(enc))
                    print(f"SUCCESS! Password is: {word} (encoding: {enc})")
                    return
                except:
                    continue
        print("Failed.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    crack()

# Quarantine Drop (Malicious Metadata Artifacts)

Use this folder to stash any files that carry suspicious xattrs (e.g., iCloud markers, resource forks) so they stay isolated from the main protocol workspace. Keep hazardous binaries here and reference them indirectly (hashes, attribute dumps) when writing Ellis artifacts.

## Handling Rules
- Drop files directly into this directory; avoid opening them elsewhere in the repo.
- Do not run `xattr`/`mdls` inside Ellis unless you must—prefer copying them here first, then capturing metadata from this folder.
- If you need to share details with AI systems, extract safe snippets into `xattr_bundle/` instead of exposing the raw files.

You can create subfolders (e.g., `pdfs/`, `icons/`, `provenance/`) if you want to categorize different payload types.

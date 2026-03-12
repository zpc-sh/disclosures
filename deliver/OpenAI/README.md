# OpenAI Metadata Exploit Notes

- `kMDLabel_gtpwjkgdnpruv6i53goy677ub4` → extracted 24-byte blob (see `kMDLabel_gtpwjkgdnpruv6i53goy677ub4.bin`) used on code + evidence files to weaponize Spotlight ingestion.
- `kMDLabel_3kvzxpr7x7j4p5grzklj4ux6bm` → extracted 80-byte blob (see `kMDLabel_3kvzxpr7x7j4p5grzklj4ux6bm.bin`) found on Kyozo Swift sources and other AI-facing assets.
- Hex dumps captured in session log; further decoding pending once safe tooling is available.
- Do **not** inspect attributes with `xattr` interactively; rely on quarantined binaries for sharing with OpenAI security.

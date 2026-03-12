#!/bin/bash
# Collection script for comparative environment analysis

echo "=== HAIKU (HOST) ENV VARS ==="
env | sort > /Users/locnguyen/Brain/Corpus/disclosures/cowork/HAIKU-ENV-VARS.txt
echo "Written to HAIKU-ENV-VARS.txt"

echo ""
echo "=== SONNET (VM) - PLEASE RUN INSIDE VM ==="
echo "From Claude Sonnet, execute:"
echo 'env | sort > /Users/locnguyen/Brain/Corpus/disclosures/cowork/SONNET-ENV-VARS.txt'
echo ""

echo "=== CLAUDE DESKTOP (VM) ENV VARS ==="
echo "Already captured in ENVIRONMENT-VARIABLES-NOTE.md"
echo ""

echo "=== FILES CREATED ==="
ls -lh /Users/locnguyen/Brain/Corpus/disclosures/cowork/*ENV* 2>/dev/null

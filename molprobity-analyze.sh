#!/bin/bash

# MolProbity One-Line Analysis Script
# Usage: ./molprobity-analyze.sh <input.pdb>

# 1. Setup Environment
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [ -f "build/setpaths.sh" ]; then
    source build/setpaths.sh
elif [ -f "$SCRIPT_DIR/build/setpaths.sh" ]; then
    source "$SCRIPT_DIR/build/setpaths.sh"
elif [ -f "$SCRIPT_DIR/../build/setpaths.sh" ]; then
    source "$SCRIPT_DIR/../build/setpaths.sh"
else
    echo "Error: build/setpaths.sh not found."
    echo "Please ensure you have run the installer and are in the correct directory."
    exit 1
fi

INPUT_PDB=$1

if [ -z "$INPUT_PDB" ]; then
    echo "Usage: $0 <input.pdb>"
    exit 1
fi

if [ ! -f "$INPUT_PDB" ]; then
    echo "Error: File $INPUT_PDB not found."
    exit 1
fi

BASENAME=$(basename "$INPUT_PDB" .pdb)
OUTPUT_DIR="mp_analysis_${BASENAME}"
mkdir -p "$OUTPUT_DIR"

echo "==============================================================================="
echo " MolProbity Analysis: $INPUT_PDB"
echo " Results will be stored in: $OUTPUT_DIR"
echo "==============================================================================="

# Step 1: Add Hydrogens (Reduce)
echo "[1/5] Adding Hydrogens (phenix.reduce)..."
phenix.reduce -quiet -build "$INPUT_PDB" > "$OUTPUT_DIR/${BASENAME}_withH.pdb"
PDB_WITH_H="$OUTPUT_DIR/${BASENAME}_withH.pdb"

# Step 2: Clashscore
echo "[2/5] Calculating Clashscore (phenix.clashscore)..."
phenix.clashscore b_factor_cutoff=40 keep_hydrogens=True "$PDB_WITH_H" > "$OUTPUT_DIR/clashscore.txt"

# Step 3: Ramachandran Analysis
echo "[3/5] Ramachandran Analysis (phenix.ramalyze)..."
phenix.ramalyze "$PDB_WITH_H" > "$OUTPUT_DIR/ramachandran.txt"

# Step 4: Rotamer Analysis
echo "[4/5] Rotamer Analysis (phenix.rotalyze)..."
phenix.rotalyze "$PDB_WITH_H" > "$OUTPUT_DIR/rotamers.txt"

# Step 5: Protein Geometry (C-beta & Omega)
echo "[5/6] Protein Geometry (C-beta & Omega)..."
phenix.cbetadev "$PDB_WITH_H" > "$OUTPUT_DIR/cbeta.txt"
phenix.omegalyze nontrans_only=False "$PDB_WITH_H" > "$OUTPUT_DIR/omega.txt"

# Step 6: Geometry Validation (Bonds & Angles)
echo "[6/6] Geometry Validation (mmtbx.mp_geo)..."
mmtbx.mp_geo pdb="$PDB_WITH_H" outliers_only=False bonds_and_angles=True > "$OUTPUT_DIR/geometry.txt"

echo "==============================================================================="
echo " SUMMARY REPORT"
echo "==============================================================================="

# Extract Clashscore
CLASHSCORE=$(grep "clashscore =" "$OUTPUT_DIR/clashscore.txt" | awk '{print $NF}')

# Extract Ramachandran
RAMA_FAV_PCT=$(grep "SUMMARY:" "$OUTPUT_DIR/ramachandran.txt" | grep "favored" | awk '{print $2}' | sed 's/%//')
RAMA_OUT_PCT=$(grep "SUMMARY:" "$OUTPUT_DIR/ramachandran.txt" | grep "outliers" | awk '{print $2}' | sed 's/%//')

# Extract Rotamers
ROTA_OUT_PCT=$(grep "SUMMARY:" "$OUTPUT_DIR/rotamers.txt" | grep "outliers" | awk '{print $2}' | sed 's/%//')

# Extract Geometry Outliers (Bonds & Angles)
BOND_REPORT=$(awk -F: '$7 ~ /\-\-/ { total++; if ($9+0 > 4.0 || $9+0 < -4.0) bad++ } END { if (total > 0) printf "%d / %d (%.2f%%)", bad+0, total+0, 100*bad/total; else print "0 / 0" }' "$OUTPUT_DIR/geometry.txt")
ANGLE_REPORT=$(awk -F: '$7 ~ /[^-]\-[^-]/ && $7 !~ /\-\-/ { total++; if ($9+0 > 4.0 || $9+0 < -4.0) bad++ } END { if (total > 0) printf "%d / %d (%.2f%%)", bad+0, total+0, 100*bad/total; else print "0 / 0" }' "$OUTPUT_DIR/geometry.txt")

# Extract C-beta and Omega
CBETA_OUT=$(grep "SUMMARY:" "$OUTPUT_DIR/cbeta.txt" | awk '{print $2}')
CIS_PRO=$(grep "cis prolines" "$OUTPUT_DIR/omega.txt" | awk '{print $2 " / " $7}')
OTHER_CIS=$(grep "other cis residues" "$OUTPUT_DIR/omega.txt" | awk '{print $2 " / " $8}')

# Calculate MolProbity Score
# Formula: 0.42574*ln(1+cs) + 0.32996*ln(1+max(0,ro-1)) + 0.24979*ln(1+max(0,(100-fav)-2)) + 0.5
MP_SCORE=$(python -c "import math; cs=$CLASHSCORE; ro=$ROTA_OUT_PCT; fav=$RAMA_FAV_PCT; ra=100.0-fav; score = 0.42574*math.log(1+cs) + 0.32996*math.log(1+max(0,ro-1)) + 0.24979*math.log(1+max(0,ra-2)) + 0.5; print(f'{score:.2f}')")

echo "==============================================================================="
echo " SUMMARY REPORT"
echo "==============================================================================="
echo "Clashscore:          $CLASHSCORE"
echo "MolProbity Score:    $MP_SCORE"
echo "Ramachandran:        Favored=$RAMA_FAV_PCT%, Outliers=$RAMA_OUT_PCT%"
echo "Rotamer Outliers:    $ROTA_OUT_PCT%"
echo "C-beta Deviations:   $CBETA_OUT"
echo "Cis-Peptides:        Pro=$CIS_PRO, Other=$OTHER_CIS"
echo "Bad Bonds:           $BOND_REPORT"
echo "Bad Angles:          $ANGLE_REPORT"
echo "==============================================================================="
echo "Detailed logs are available in $OUTPUT_DIR/"

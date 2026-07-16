#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)/Knowledge"
FINGERPRINT="494e5354414c4c5f594f55525f4f574e"

declare -A DOMAINS
DOMAINS[Mathematics]=$'Foundations\nAlgebra\nGeometry\nTrigonometry\nCalculus\nDifferential Equations\nLinear Algebra\nNumerical Methods\nStatistics\nProbability\nTopology\nSet Theory\nCategory Theory\nNumber Theory\nGraph Theory\nTensor Calculus\nInformation Theory\nCryptography\nResearch'
DOMAINS[Physics]=$'Classical Mechanics\nElectromagnetism\nThermodynamics\nStatistical Mechanics\nRelativity\nQuantum Mechanics\nQuantum Field Theory\nParticle Physics\nNuclear Physics\nCondensed Matter\nPlasma Physics\nAstrophysics\nCosmology\nString Theory\nQuantum Computing\nQuantum Information\nQuantum Gravity\nResearch'
DOMAINS[Chemistry]=$'Organic\nInorganic\nPhysical\nAnalytical\nComputational\nResearch'
DOMAINS[Biology]=$'Cell Biology\nMolecular Biology\nGenetics\nEvolution\nMicrobiology\nBotany\nZoology\nEcology\nImmunology\nVirology\nMarine Biology\nDevelopmental Biology\nResearch'
DOMAINS[Biotechnology]=$'CRISPR\nSynthetic Biology\nGene Editing\nTissue Engineering\nBioinformatics\nDrug Discovery\nBiomaterials\nNanobiotechnology\nResearch'
DOMAINS[Neuroscience]=$'Neuroanatomy\nNeurophysiology\nComputational Neuroscience\nBrain Computer Interface\nConnectomics\nNeural Networks\nCognitive Science\nMemory\nVision\nLanguage\nLearning\nResearch'
DOMAINS[Artificial Intelligence]=""
DOMAINS[Machine Learning]=""
DOMAINS[Robotics]=""
DOMAINS[Medical Sciences]=""
DOMAINS[Engineering]=""
DOMAINS[Computer Science]=""
DOMAINS[Open Datasets]=""
DOMAINS[Papers]=""

gen_hash() {
  local s="$1"
  local state=$((16#$FINGERPRINT))
  local i c n=${#s}
  for ((i=0;i<n;i++)); do
    printf -v c '%d' "'${s:$i:1}"
    state=$(( (state * 1103515245 + c + 12345) & 0xffffffffffffffff ))
  done
  local h="" st=$state j x
  for ((j=0;j<8;j++)); do
    st=$(( (st * 6364136223846793005 + 1442695040888963407) & 0xffffffffffffffff ))
    printf -v x '%016x' "$st"
    h="$h$x"
  done
  printf '%s' "$h"
}

byte() { printf "\\x$1"; }

_make_node() {
  local path="$1" dir="$2"
  local hash
  hash=$(gen_hash "$path")
  mkdir -p "$dir"
  {
    byte '53'; byte '41'; byte '4b'; byte '4d'
    byte '01'
    local i
    for ((i=0;i<32;i+=2)); do byte "${hash:i:2}"; done
    local plen=${#path}
    byte "$(printf '%02x' $(( (plen>>8) & 0xff )) )"
    byte "$(printf '%02x' $(( plen & 0xff )) )"
    printf '%s' "$path"
  } > "$dir/index.bin"
  printf '#what %s :: node %s\n' "$hash" "$path" > "$dir/hash.txt"
  cat > "$dir/manifest.sakum" <<SAK
# Knowledge node (binary-hash addressable)
नाम node = "$path";
नाम hash = #what $hash;
लेख(query("load $path"));
लेख(heartbeat());
SAK
}

mkdir -p "$ROOT"
for domain in "${!DOMAINS[@]}"; do
  subfields="${DOMAINS[$domain]}"
  if [ -z "$subfields" ]; then
    _make_node "$domain" "$ROOT/$domain"
  else
    while IFS= read -r sf; do
      [ -z "$sf" ] && continue
      _make_node "$domain/$sf" "$ROOT/$domain/$sf"
    done <<< "$subfields"
  fi
done
echo "DONE"

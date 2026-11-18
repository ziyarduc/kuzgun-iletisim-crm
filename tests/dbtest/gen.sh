#!/usr/bin/env bash
# exe/Program.cs'teki veri katmani ve anlik goruntu bloklarini test projesine tasir ve calistirir.
set -euo pipefail
cd "$(dirname "$0")"
SRC=../../exe/Program.cs
S1=$(grep -n "// ---- Veritabani katmani" $SRC | cut -d: -f1)
E1=$(grep -n "private static List<Dictionary<string, object>> CreateDemoDevices" $SRC | cut -d: -f1)
S2=$(grep -n "// ---- Anlik goruntuler" $SRC | cut -d: -f1)
E2=$(grep -n "private static void CheckPinUnlocked" $SRC | cut -d: -f1)
{ cat shim.part; sed -n "${S1},$((E1-1))p" $SRC; sed -n "${S2},$((E2-1))p" $SRC; cat tail.part; } > Program.cs
~/.dotnet/dotnet run "$@"

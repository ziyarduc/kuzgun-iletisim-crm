#!/usr/bin/env bash
# Kuzgun CRM kurulum EXE derleme (Roslyn csc + .NET 4.0 referans paketleri). Tailwind CSS onceden derlenmis halde assets/ altindadir.
set -euo pipefail
cd "$(dirname "$0")"
R=${NET40_REF:-$HOME/.nuget/packages/microsoft.netframework.referenceassemblies.net40/1.0.3/build/.NETFramework/v4.0}
CSC=${CSC_DLL:-$HOME/.dotnet/sdk/10.0.403/Roslyn/bincore/csc.dll}
A=../assets
RES=()
for f in vue.global.prod.js tailwind.css css/fa.min.css webfonts/fa-solid-900.woff2 webfonts/fa-regular-400.woff2 webfonts/fa-brands-400.woff2 webfonts/fa-v4compatibility.woff2; do
  RES+=("/resource:$A/$f,asset.${f//\//.}")
done
(cd exe && "$HOME/.dotnet/dotnet" "$CSC" /nologo /noconfig /nostdlib+ /target:exe /platform:anycpu /optimize+ \
  /main:KuzgunCrmSetup.Program /win32icon:kuzgun.ico /out:../KuzgunCRM_Kurulum.exe \
  /r:$R/mscorlib.dll /r:$R/System.dll /r:$R/System.Core.dll /r:$R/System.Windows.Forms.dll /r:$R/System.Drawing.dll /r:$R/System.Web.Extensions.dll \
  Program.cs \
  /resource:../Kurulum.ps1,payload.Kurulum.ps1 /resource:../Code.gs,payload.Code.gs \
  /resource:../Kuzgun_Iletisim_CRM.html,payload.Kuzgun_Iletisim_CRM.html /resource:../appsscript.json,payload.appsscript.json \
  /resource:../README.md,payload.README.md "${RES[@]}")
echo "BUILD OK: $(ls -lh KuzgunCRM_Kurulum.exe | awk '{print $5}')"

@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title MC Vanilla Downloader

:: CONFIG
set "MC_DIR=%~dp0.minecraft"
set "MANIFEST=https://bmclapi2.bangbang93.com/mc/game/version_manifest_v2.json"

:main
cls
echo.
echo   MC VANILLA DOWNLOADER (Windows)
echo   --------------------------------
echo   1) List versions
echo   2) Download (jar + libs, no assets)
echo   3) Download (jar + libs + assets)
echo   4) Set game directory (Current: !MC_DIR!)
echo   5) Exit
echo.
set "sel="
set /p "sel=> Input number: "

if "!sel!"=="1" goto list
if "!sel!"=="2" goto dl_noasset
if "!sel!"=="3" goto dl_asset
if "!sel!"=="4" goto setdir
if "!sel!"=="5" exit /b
goto main

:list
cls
echo Fetch manifest...
powershell -NoLogo -ExecutionPolicy Bypass -Command "$m=Invoke-RestMethod '%MANIFEST%'; Write-Host ('Latest release: '+$m.latest.release); Write-Host ('Latest snapshot: '+$m.latest.snapshot); Write-Host ''; $m.versions | Select-Object -First 25 | ForEach-Object { Write-Host ('  '+$_.id+'  ['+$_.type+']') }"
pause
goto main

:setdir
set /p "MC_DIR=Input new game root (blank to cancel): "
if "!MC_DIR!"=="" set "MC_DIR=%~dp0.minecraft"
goto main

:dl_noasset
set "ASSETS=0"
goto askver

:dl_asset
set "ASSETS=1"
goto askver

:askver
set "VER="
set /p "VER=Input version (eg 1.12.2): "
if "!VER!"=="" goto main

powershell -NoLogo -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';function Get-Sha1{param([string]$Path);$sha=[System.Security.Cryptography.SHA1]::Create();$bytes=[System.IO.File]::ReadAllBytes($Path);return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-','').ToLower()};$manifest=Invoke-RestMethod('%MANIFEST%');$verEntry=$manifest.versions|Where-Object{$_.id -eq '!VER!'};if(-not $verEntry){Write-Host 'ERROR: Version not found';exit 1};$vm=Invoke-RestMethod($verEntry.url);$root='!MC_DIR!';$vdir=Join-Path (Join-Path $root 'versions') '!VER!';New-Item -ItemType Directory -Force -Path $vdir|Out-Null;$jsonPath=Join-Path $vdir ('!VER!'+'.json');$vm|ConvertTo-Json -Depth 20|Set-Content $jsonPath -Encoding UTF8;Write-Host '[OK] Version json: !VER!.json';$client=$vm.downloads.client;$jarPath=Join-Path $vdir ('!VER!'+'.jar');if(-not (Test-Path $jarPath) -or (Get-Sha1 $jarPath) -ne $client.sha1){Invoke-WebRequest $client.url -OutFile $jarPath;Write-Host ('[OK] Client jar '+[math]::Round($client.size/1MB,2)+' MB')}else{Write-Host '[SKIP] Jar exists and hash ok'};$libRoot=Join-Path $root 'libraries';New-Item -ItemType Directory -Force -Path $libRoot|Out-Null;foreach($lib in $vm.libraries){$allow=$true;if($lib.rules){$allow=$false;foreach($rule in $lib.rules){$matchOs=(-not $rule.os.name) -or ($rule.os.name -eq 'windows');if($matchOs){if($rule.action -eq 'allow'){$allow=$true}elseif($rule.action -eq 'disallow'){$allow=$false}}}}if(-not $allow){continue};$dl=$lib.downloads;if($dl.artifact){$art=$dl.artifact;$dst=Join-Path $libRoot $art.path;New-Item -ItemType Directory -Force -Path (Split-Path $dst)|Out-Null;if(-not (Test-Path $dst) -or (Get-Sha1 $dst) -ne $art.sha1){Invoke-WebRequest $art.url -OutFile $dst}};if($lib.natives.windows -and $dl.classifiers){$nativeKey=$lib.natives.windows;$native=$dl.classifiers.$nativeKey;if($native){$dst=Join-Path $libRoot $native.path;New-Item -ItemType Directory -Force -Path (Split-Path $dst)|Out-Null;if(-not (Test-Path $dst) -or (Get-Sha1 $dst) -ne $native.sha1){Invoke-WebRequest $native.url -OutFile $dst}}}};Write-Host '[OK] Libraries done';if($vm.assetIndex){$ai=$vm.assetIndex;$idxDir=Join-Path (Join-Path $root 'assets') 'indexes';New-Item -ItemType Directory -Force -Path $idxDir|Out-Null;$idxPath=Join-Path $idxDir ($ai.id+'.json');Invoke-WebRequest $ai.url -OutFile $idxPath;Write-Host ('[OK] Asset index: '+$ai.id+'.json');if('!ASSETS!' -eq '1'){$idxObj=Invoke-RestMethod $ai.url;$objDir=Join-Path (Join-Path $root 'assets') 'objects';$count=0;foreach($item in $idxObj.objects.GetEnumerator()){$hash=$item.Value.hash;$sub=$hash.Substring(0,2);$dst=Join-Path (Join-Path $objDir $sub) $hash;New-Item -ItemType Directory -Force -Path (Split-Path $dst)|Out-Null;if(-not (Test-Path $dst)){$url='https://bmclapi2.bangbang93.com/assets/'+$sub+'/'+$hash;Invoke-WebRequest $url -OutFile $dst};$count++;if($count%50 -eq 0){Write-Host ('    Assets downloaded: '+$count)}};Write-Host ('[OK] Total assets: '+$count)}};Write-Host '';Write-Host 'FINISHED! Refresh in HMCL / PCL2'"

echo.
pause
goto main

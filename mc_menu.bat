@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title MC Vanilla Downloader

:: ============ 配置区 ============
set "MC_DIR=%~dp0.minecraft"
set "MANIFEST=https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
:: ================================

:main
cls
echo.
echo   ⛏  MC VANILLA DOWNLOADER (Windows)
echo   ─────────────────────────────────
echo   1) 列出可下载版本
echo   2) 下载指定版本（仅本体 + 库）
echo   3) 下载指定版本（含资源文件）
echo   4) 设置游戏目录（当前: %MC_DIR%）
echo   5) 退出
echo.
set "sel="
set /p "sel=> 输入数字: "

if "%sel%"=="1" goto list
if "%sel%"=="2" goto dl_noasset
if "%sel%"=="3" goto dl_asset
if "%sel%"=="4" goto setdir
if "%sel%"=="5" exit /b
goto main

:list
cls
echo 正在拉取版本清单...
powershell -NoLogo -Command "$m=Invoke-RestMethod '%MANIFEST%'; Write-Host ('最新正式版: '+$m.latest.release); Write-Host ('最新快照:   '+$m.latest.snapshot); Write-Host ''; $m.versions | Select-Object -First 25 | ForEach-Object { Write-Host ('  '+$_.id+'  ['+$_.type+']') }"
pause
goto main

:setdir
set /p "MC_DIR=输入新的游戏根目录（留空取消）: "
if "%MC_DIR%"=="" set "MC_DIR=%~dp0.minecraft"
goto main

:dl_noasset
set "ASSETS=0"
goto askver

:dl_asset
set "ASSETS=1"
goto askver

:askver
set /p "VER=输入要下载的版本号（如 1.20.1）: "
if "%VER%"=="" goto main
call :download "%VER%" "%ASSETS%"
pause
goto main

:: ============ 下载核心 ============
:download
set "VER=%~1"
set "WITH_ASSETS=%~2"

powershell -NoLogo -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; function Sha1($p){$s=[System.Security.Cryptography.SHA1]::Create();$b=[IO.File]::ReadAllBytes($p);[BitConverter]::ToString($s.ComputeHash($b)).Replace('-','').ToLower()}; $manifest=Invoke-RestMethod '%MANIFEST%'; $vu=($manifest.versions|Where-Object{$_.id -eq '%VER%'}).url; if(!$vu){Write-Host '版本不存在';exit 1}; $vm=Invoke-RestMethod $vu; $root='%MC_DIR%'; $vdir=Join-Path $root 'versions' '%VER%'; New-Item -ItemType Directory -Force -Path $vdir|Out-Null; $json=Join-Path $vdir ('%VER%'+'.json'); $vm|ConvertTo-Json -Depth 15|Set-Content $json -Encoding UTF8; Write-Host ('[ok] 版本元数据 '+('%VER%'+'.json')); $c=$vm.downloads.client; $jar=Join-Path $vdir ('%VER%'+'.jar'); if(!(Test-Path $jar) -or (Sha1 $jar)-ne $c.sha1){Invoke-WebRequest $c.url -OutFile $jar; Write-Host ('[ok] 客户端 jar '+[math]::Round($c.size/1MB)+'MB')}else{Write-Host '[skip] jar 已存在'}; New-Item -ItemType Directory -Force -Path (Join-Path $root 'libraries')|Out-Null; foreach($lib in $vm.libraries){ $ok=$true; foreach($r in $lib.rules){if($r.action-eq'allow' -and $r.os.name -and $r.os.name-ne'windows'){$ok=$false}}; if($lib.rules.Count -eq 0){$ok=$true}; if(!$ok){continue}; $d=$lib.downloads; if($d.artifact){$a=$d.artifact; $dst=Join-Path $root 'libraries' $a.path; New-Item -ItemType Directory -Force -Path (Split-Path $dst)|Out-Null; if(!(Test-Path $dst)-or (Sha1 $dst)-ne $a.sha1){Invoke-WebRequest $a.url -OutFile $dst}}; if($lib.natives.windows -and $d.classifiers.($lib.natives.windows)){$n=$d.classifiers.($lib.natives.windows); $dst=Join-Path $root 'libraries' $n.path; New-Item -ItemType Directory -Force -Path (Split-Path $dst)|Out-Null; if(!(Test-Path $dst)-or (Sha1 $dst)-ne $n.sha1){Invoke-WebRequest $n.url -OutFile $dst}} }; Write-Host '[ok] 依赖库下载完成'; if($vm.assetIndex){$ai=$vm.assetIndex; $idx=Join-Path $root 'assets' 'indexes' ($ai.id+'.json'); New-Item -ItemType Directory -Force -Path (Split-Path $idx)|Out-Null; Invoke-WebRequest $ai.url -OutFile $idx; Write-Host ('[ok] 资源索引 '+($ai.id)+'.json')}; if('%WITH_ASSETS%' -eq '1' -and $vm.assetIndex){ $idxObj=Invoke-RestMethod $ai.url; $objDir=Join-Path $root 'assets' 'objects'; $i=0; foreach($o in $idxObj.objects.GetEnumerator()){$h=$o.Value.hash; $dst=Join-Path $objDir $h.Substring(0,2) $h; New-Item -ItemType Directory -Force -Path (Split-Path $dst)|Out-Null; if(!(Test-Path $dst)){Invoke-WebRequest ('https://resources.download.minecraft.net/'+$h.Substring(0,2)+'/'+$h) -OutFile $dst}; $i++; if($i%%50-eq0){Write-Host ('    资源 '+$i)}}; Write-Host ('[ok] 资源文件 '+$i+' 个')}; Write-Host ''; Write-Host ('完成！去 PCL2 / HMCL 刷新即可看到 %VER%')"
goto :eof

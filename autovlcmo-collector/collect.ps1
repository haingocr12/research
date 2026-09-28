#requires -version 5.1
<#
  collect.ps1 - Thu thap du lieu chan doan cua AutoVLCMO (game ban PC) trong luc chay.
  CHI DOC va SAO CHEP. Khong sua, khong ghi, khong inject gi vao auto hay game.

  Y tuong:
    - Chup "anh" thu muc cai auto TRUOC khi chay (duong dan + kich thuoc + gio sua + SHA256).
    - Trong luc auto chay: dinh ky ghi lai cac tien trinh lien quan (ten, PID, tien trinh cha,
      dong lenh, va danh sach module/DLL ma game + MctHost dang nap).
    - Khi ban nhan Q de dung: chup lai thu muc, so sanh voi luc dau de biet MctHost
      da bung ra / tao them nhung file nao, roi sao chep cac file MOI hoac BI DOI + log + config
      vao mot thu muc Output, nen thanh .zip de ban gui lai.

  Cach dung:
    1. Copy ca thu muc nay ra PC Windows.
    2. Chuot phai run.bat -> Run as administrator (de doc duoc dong lenh + module cua tien trinh khac).
    3. Doi thay chu "San sang" thi mo auto va dung nhu binh thuong vai phut.
    4. Quay lai cua so nay, nhan Q de dung. File Output_<gio>.zip nam canh script.

  Tham so (khong bat buoc):
    -AutoDir "D:\AutoVLCMO"   thu muc cai auto. Bo trong = tu tim tu tien trinh AutoVLCMO.exe.
    -Interval 5              so giay giua moi lan chup tien trinh (mac dinh 5).
    -MaxCopyMB 25           file lon hon nguong nay se khong copy, chi ghi lai thong tin (mac dinh 25).
#>
param(
    [string]$AutoDir  = '',
    [int]   $Interval = 5,
    [int]   $MaxCopyMB = 25
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ---- thu muc lam viec -------------------------------------------------------
$Root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Out   = Join-Path $Root "Output_$Stamp"
$null  = New-Item -ItemType Directory -Force -Path $Out, (Join-Path $Out 'files'), (Join-Path $Out 'proc')

function Log([string]$File,[string]$Msg){
    Add-Content -LiteralPath (Join-Path $Out $File) -Value $Msg -Encoding UTF8
}
function Say([string]$Msg,[string]$Color='Gray'){
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'),$Msg) -ForegroundColor $Color
    Log 'collector.log' ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'),$Msg)
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $IsAdmin){ Say 'Chua chay bang Administrator -> co the thieu dong lenh/module cua tien trinh.' 'Yellow' }

# Ten cac tien trinh muon theo doi (auto, game PC, host)
$InterestRx = '(?i)^(AutoVLCMO|MctHost|VLCM|VoLam|game|client)'

# ---- 1. tim thu muc auto ----------------------------------------------------
function Get-AutoProc {
    Get-CimInstance Win32_Process -Filter "Name='AutoVLCMO.exe'" -ErrorAction SilentlyContinue |
        Select-Object -First 1
}
if(-not $AutoDir){
    $p = Get-AutoProc
    if($p -and $p.ExecutablePath){ $AutoDir = Split-Path -Parent $p.ExecutablePath }
}
if(-not $AutoDir -or -not (Test-Path -LiteralPath $AutoDir)){
    Say 'Chua xac dinh duoc thu muc auto. Ban co the mo auto truoc roi chay lai, hoac dung -AutoDir "duong_dan".' 'Yellow'
} else {
    Say ("Thu muc auto: {0}" -f $AutoDir) 'Cyan'
}

# ---- 2. ham chup anh thu muc (path/size/mtime/sha256) -----------------------
function Snapshot-Dir([string]$Dir){
    $map = @{}
    if(-not $Dir -or -not (Test-Path -LiteralPath $Dir)){ return $map }
    Get-ChildItem -LiteralPath $Dir -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $sha = $null
        try { if($_.Length -le ($MaxCopyMB*1MB)){ $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } } catch {}
        $map[$_.FullName] = [pscustomobject]@{
            Path=$_.FullName; Size=$_.Length; MTime=$_.LastWriteTime; Sha256=$sha
        }
    }
    return $map
}

Say 'Chup anh thu muc auto luc bat dau...' 'Gray'
$before = Snapshot-Dir $AutoDir
$before.Values | Sort-Object Path | Format-Table -Auto Size,MTime,Sha256,Path |
    Out-String -Width 4000 | Set-Content -LiteralPath (Join-Path $Out 'snapshot_before.txt') -Encoding UTF8
Say ("Da ghi {0} file vao snapshot_before.txt" -f $before.Count) 'Gray'

# ---- 3. ham chup tien trinh + module ----------------------------------------
function Snapshot-Proc([int]$n){
    $file = Join-Path $Out ('proc\proc_{0:D4}.txt' -f $n)
    "==== {0} ====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Set-Content -LiteralPath $file -Encoding UTF8

    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match $InterestRx }
    foreach($pr in $procs){
        ("PID {0}  PPID {1}  {2}" -f $pr.ProcessId,$pr.ParentProcessId,$pr.Name) | Add-Content $file -Encoding UTF8
        ("  Path: {0}" -f $pr.ExecutablePath) | Add-Content $file -Encoding UTF8
        ("  Cmd : {0}" -f $pr.CommandLine)    | Add-Content $file -Encoding UTF8
        # danh sach module/DLL dang nap (doc-only). Giup thay DLL la ma MctHost inject vao game.
        try {
            $mods = (Get-Process -Id $pr.ProcessId -ErrorAction Stop).Modules |
                    Select-Object -ExpandProperty FileName -ErrorAction SilentlyContinue
            "  Modules:" | Add-Content $file -Encoding UTF8
            $mods | Sort-Object -Unique | ForEach-Object { "    $_" | Add-Content $file -Encoding UTF8 }
        } catch { "  (khong doc duoc module: $($_.Exception.Message))" | Add-Content $file -Encoding UTF8 }
        "" | Add-Content $file -Encoding UTF8
    }
    return ($procs | Measure-Object).Count
}

# ---- 4. vong lap tan ket thuc bang phim Q ------------------------------------
Say '========================================================' 'Green'
Say ' San sang. HAY MO AUTO va dung binh thuong vai phut.' 'Green'
Say ' Nhan Q trong cua so nay de dung va dong goi ket qua.' 'Green'
Say '========================================================' 'Green'

$i = 0
while($true){
    if([Console]::KeyAvailable){
        $k = [Console]::ReadKey($true)
        if($k.Key -eq 'Q'){ break }
    }
    $i++
    $c = Snapshot-Proc $i
    Say ("Lan chup #{0}: thay {1} tien trinh lien quan." -f $i,$c) 'DarkGray'
    Start-Sleep -Seconds $Interval
}

# ---- 5. so sanh thu muc + sao chep file moi/doi -----------------------------
Say 'Chup anh thu muc auto luc ket thuc va so sanh...' 'Gray'
$after = Snapshot-Dir $AutoDir
$after.Values | Sort-Object Path | Format-Table -Auto Size,MTime,Sha256,Path |
    Out-String -Width 4000 | Set-Content -LiteralPath (Join-Path $Out 'snapshot_after.txt') -Encoding UTF8

$changed = New-Object System.Collections.Generic.List[object]
foreach($k in $after.Keys){
    $a = $after[$k]; $b = $before[$k]
    if(-not $b){                       $a | Add-Member NoteProperty State 'NEW'     -Force; $changed.Add($a) }
    elseif($b.Sha256 -ne $a.Sha256 -or $b.Size -ne $a.Size){
                                       $a | Add-Member NoteProperty State 'CHANGED' -Force; $changed.Add($a) }
}
$changed | Sort-Object State,Path | Format-Table -Auto State,Size,MTime,Path |
    Out-String -Width 4000 | Set-Content -LiteralPath (Join-Path $Out 'changed_files.txt') -Encoding UTF8
Say ("So file moi/bi doi: {0} (xem changed_files.txt)" -f $changed.Count) 'Cyan'

# Chi copy cac dinh dang du lieu/cau hinh/ma nho -> tranh lay lai chinh exe goc
$copyExt = '\.(dll|so|xml|ini|cfg|conf|json|txt|log|db|dat|bin|lua|script)$'
foreach($f in $changed){
    if($f.Size -gt ($MaxCopyMB*1MB)){ continue }
    if($f.Path -notmatch $copyExt){ continue }
    try {
        $rel  = $f.Path.Substring($AutoDir.Length).TrimStart('\')
        $dest = Join-Path (Join-Path $Out 'files') $rel
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest)
        Copy-Item -LiteralPath $f.Path -Destination $dest -Force
    } catch { Say ("Khong copy duoc {0}: {1}" -f $f.Path,$_.Exception.Message) 'Yellow' }
}

# ghi vai thong tin he thong co ban
"Time      : {0}"  -f (Get-Date)                     | Set-Content (Join-Path $Out 'system.txt') -Encoding UTF8
"AutoDir   : {0}"  -f $AutoDir                        | Add-Content (Join-Path $Out 'system.txt') -Encoding UTF8
"OS        : {0}"  -f (Get-CimInstance Win32_OperatingSystem).Caption | Add-Content (Join-Path $Out 'system.txt') -Encoding UTF8
"Admin     : {0}"  -f $IsAdmin                        | Add-Content (Join-Path $Out 'system.txt') -Encoding UTF8

# ---- 6. nen thanh zip -------------------------------------------------------
$zip = Join-Path $Root ("Output_{0}.zip" -f $Stamp)
try {
    if(Test-Path $zip){ Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $Out '*') -DestinationPath $zip -Force
    Say ("XONG. Gui lai file nay cho nguoi phan tich: {0}" -f $zip) 'Green'
} catch {
    Say ("Khong nen duoc zip: {0}. Ban co the tu nen thu muc {1}." -f $_.Exception.Message,$Out) 'Yellow'
}

Write-Host ''
Write-Host 'Nhan Enter de dong...' -ForegroundColor Green
[void][Console]::ReadLine()

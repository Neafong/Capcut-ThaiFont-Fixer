# CapCut PC Thai Font & Scale Fixer
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "     เครื่องมือแก้ไขฟอนต์และเมนูภาษาไทยสำหรับ CapCut PC" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check if CapCut is running
$running = Get-Process -Name "CapCut" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "[!] ตรวจพบว่า CapCut กำลังเปิดใช้งานอยู่" -ForegroundColor Yellow
    Write-Host "    กรุณากดปิดโปรแกรม CapCut ก่อนดำเนินการต่อค่ะ" -ForegroundColor Yellow
    Write-Host ""
    $ans = Read-Host "ปิดโปรแกรมเรียบร้อยแล้วใช่ไหมคะ? (กด Enter เพื่อดำเนินการต่อ หรือพิมพ์ Q เพื่อยกเลิก)"
    if ($ans -eq "Q" -or $ans -eq "q") {
        Write-Host "ยกเลิกการทำงานเรียบร้อยค่ะ" -ForegroundColor Red
        exit 0
    }
    $runningAgain = Get-Process -Name "CapCut" -ErrorAction SilentlyContinue
    if ($runningAgain) {
        Write-Host "[X] โปรแกรม CapCut ยังเปิดค้างอยู่ กรุณาปิดโปรแกรมให้สนิทก่อนนะคะ" -ForegroundColor Red
        exit 1
    }
}

# 2. Locate CapCut directory
$appsRoot = "$env:LOCALAPPDATA\CapCut\Apps"
if (-not (Test-Path $appsRoot)) {
    Write-Host "[X] ไม่พบตำแหน่งการติดตั้ง CapCut ที่ $appsRoot" -ForegroundColor Red
    exit 1
}

$versionDir = Get-ChildItem -Path $appsRoot -Directory | Where-Object { $_.Name -match '^\d+\.' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $versionDir) {
    Write-Host "[X] ไม่พบโฟลเดอร์เวอร์ชันของ CapCut" -ForegroundColor Red
    exit 1
}

$systemFontDir = Join-Path $versionDir.FullName "Resources\Font\SystemFont"
if (-not (Test-Path $systemFontDir)) {
    Write-Host "[X] ไม่พบโฟลเดอร์ SystemFont ในเวอร์ชัน $($versionDir.Name)" -ForegroundColor Red
    exit 1
}

Write-Host "[✓] ตรวจพบ CapCut เวอร์ชัน: $($versionDir.Name)" -ForegroundColor Green

# 3. Scale input
Write-Host ""
Write-Host "เลือกขนาดสเกลเมนูที่ต้องการ (ค่าแนะนำคือ 1.2):" -ForegroundColor White
Write-Host "  1. ขนาด 1.2 เท่า (120%) - แนะนำสำหรับจอ 1080p พอดีสายตา" -ForegroundColor Gray
Write-Host "  2. ขนาด 1.25 เท่า (125%) - ใหญ่ขึ้นอีกนิด" -ForegroundColor Gray
Write-Host "  3. ขนาด 1.5 เท่า (150%) - ขนาดใหญ่พิเศษ" -ForegroundColor Gray
Write-Host "  4. ขนาดปกติ 1.0 เท่า (100%) - ไม่ขยายสเกล ใช้เฉพาะเปลี่ยนฟอนต์" -ForegroundColor Gray
$choice = Read-Host "กรอกตัวเลขตัวเลือก (1-4) หรือกด Enter เพื่อใช้ค่าแนะนำ [1]"

$scale = "1.2"
switch ($choice) {
    "1" { $scale = "1.2" }
    "2" { $scale = "1.25" }
    "3" { $scale = "1.5" }
    "4" { $scale = "1.0" }
    default { $scale = "1.2" }
}

Write-Host "[✓] กำหนดขนาดสเกลเป็น: ${scale}x" -ForegroundColor Green

# 4. Patch font function
function Patch-FontName($srcPath, $dstPath, $newName) {
    $bytes = [System.IO.File]::ReadAllBytes($srcPath)
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $reader = New-Object System.IO.BinaryReader($stream)
    
    $magic = $reader.ReadUInt32()
    $numTables = [System.Net.IPAddress]::NetworkToHostOrder($reader.ReadInt16())
    $stream.Seek(12, [System.IO.SeekOrigin]::Begin) | Out-Null
    
    $nameTableIndex = -1
    for ($i = 0; $i -lt $numTables; $i++) {
        $tag = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $checkSum = $reader.ReadUInt32()
        $offset = [System.Net.IPAddress]::NetworkToHostOrder($reader.ReadInt32())
        $length = [System.Net.IPAddress]::NetworkToHostOrder($reader.ReadInt32())
        if ($tag -eq "name") {
            $nameTableIndex = $i
            break
        }
    }
    $reader.Close()
    $stream.Close()
    
    if ($nameTableIndex -eq -1) { return }
    
    $strFamily = [System.Text.Encoding]::BigEndianUnicode.GetBytes($newName)
    $strSub = [System.Text.Encoding]::BigEndianUnicode.GetBytes("Regular")
    $strFull = [System.Text.Encoding]::BigEndianUnicode.GetBytes($newName)
    $strPS = [System.Text.Encoding]::BigEndianUnicode.GetBytes($newName)
    
    $records = @(
        @{ NameID = 1; Bytes = $strFamily },
        @{ NameID = 2; Bytes = $strSub },
        @{ NameID = 3; Bytes = $strFull },
        @{ NameID = 4; Bytes = $strFull },
        @{ NameID = 6; Bytes = $strPS }
    )
    
    $count = $records.Count
    $stringStorageOffset = 6 + ($count * 12)
    
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]0))
    $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]$count))
    $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]$stringStorageOffset))
    
    $currentStrOffset = 0
    foreach ($r in $records) {
        $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]3))
        $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]1))
        $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]0x0409))
        $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]$r.NameID))
        $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]$r.Bytes.Length))
        $bw.Write([System.Net.IPAddress]::HostToNetworkOrder([int16]$currentStrOffset))
        $currentStrOffset += $r.Bytes.Length
    }
    
    foreach ($r in $records) { $bw.Write($r.Bytes) }
    while (($ms.Length % 4) -ne 0) { $bw.Write([byte]0) }
    
    $newNameTableBytes = $ms.ToArray()
    $bw.Close()
    $ms.Close()
    
    $newOffset = $bytes.Length
    while (($newOffset % 4) -ne 0) { $newOffset++ }
    
    $newBytes = New-Object byte[] ($newOffset + $newNameTableBytes.Length)
    [Array]::Copy($bytes, $newBytes, $bytes.Length)
    [Array]::Copy($newNameTableBytes, 0, $newBytes, $newOffset, $newNameTableBytes.Length)
    
    $cs = [uint32]0
    for ($k = 0; $k -lt $newNameTableBytes.Length; $k += 4) {
        $val = [System.BitConverter]::ToUInt32($newNameTableBytes, $k)
        $val = [System.Net.IPAddress]::NetworkToHostOrder([int32]$val)
        $cs += [uint32]$val
    }
    
    $entryPos = 12 + ($nameTableIndex * 16)
    $streamOut = New-Object System.IO.MemoryStream(,$newBytes)
    $writerOut = New-Object System.IO.BinaryWriter($streamOut)
    $streamOut.Seek($entryPos + 4, [System.IO.SeekOrigin]::Begin) | Out-Null
    $writerOut.Write([System.Net.IPAddress]::HostToNetworkOrder([int32]$cs))
    $writerOut.Write([System.Net.IPAddress]::HostToNetworkOrder([int32]$newOffset))
    $writerOut.Write([System.Net.IPAddress]::HostToNetworkOrder([int32]$newNameTableBytes.Length))
    $writerOut.Close()
    $streamOut.Close()
    
    [System.IO.File]::WriteAllBytes($dstPath, $newBytes)
}

# 5. Patch fonts
$kanitSource = Join-Path $PSScriptRoot "..\resources\Kanit-Regular.ttf"
if (-not (Test-Path $kanitSource)) {
    Write-Host "[X] ไม่พบไฟล์ฟอนต์ Kanit ที่ $kanitSource" -ForegroundColor Red
    exit 1
}

Write-Host "[*] กำลังแปลงร่างฟอนต์และแทนที่ไฟล์ระบบ..." -ForegroundColor Cyan
$fontTargets = @("CapCutSansText-Regular", "CapCutSansText-Bold", "CapCutSansText-Medium")
foreach ($target in $fontTargets) {
    $targetPath = Join-Path $systemFontDir "$target.otf"
    $bakPath = "$targetPath.orig"
    if ((Test-Path $targetPath) -and -not (Test-Path $bakPath)) {
        Copy-Item $targetPath $bakPath
    }
    Patch-FontName $kanitSource $targetPath $target
}

# Copy to th.ttf as well
Copy-Item $kanitSource (Join-Path $systemFontDir "th.ttf") -Force
Write-Host "[✓] ติดตั้งฟอนต์ Kanit ลงในระบบ CapCut สำเร็จ" -ForegroundColor Green

# 6. Create VBS Launcher
$vbsPath = Join-Path $appsRoot "run_capcut.vbs"
$vbsContent = @"
Set oShell = CreateObject("WScript.Shell")
oShell.Environment("PROCESS")("QT_SCALE_FACTOR") = "$scale"
oShell.Run """$appsRoot\CapCut.exe""", 1, False
"@
Set-Content -Path $vbsPath -Value $vbsContent -Encoding ASCII
Write-Host "[✓] กำหนดค่าสเกลการแสดงผลแบบเฉพาะโปรแกรมสำเร็จ" -ForegroundColor Green

# 7. Update Shortcuts
$sh = New-Object -ComObject WScript.Shell
$shortcuts = @(
    "$env:USERPROFILE\Desktop\CapCut.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\CapCut\CapCut.lnk"
)
foreach ($s in $shortcuts) {
    if (Test-Path $s) {
        $link = $sh.CreateShortcut($s)
        $link.TargetPath = "wscript.exe"
        $link.Arguments = "`"$vbsPath`""
        $link.WorkingDirectory = $appsRoot
        $link.IconLocation = "$appsRoot\CapCut.exe,0"
        $link.Save()
        Write-Host "[✓] อัปเดตไอคอนทางลัด: $s" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "       แก้ไขฟอนต์และสเกลของ CapCut เสร็จสมบูรณ์แล้วค่ะ!" -ForegroundColor Green
Write-Host "     เปิดโปรแกรมจากไอคอนบนหน้าจอ Desktop ได้เลยนะคะ" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green

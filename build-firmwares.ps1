# Windows PlatformIO firmware selector and two-batch builder.
$ErrorActionPreference = 'Stop'
# WinForms needs an STA thread. PowerShell 7 commonly starts MTA, so relaunch once.
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  if ($env:BUILDS_PS1_STA_RELAUNCH -eq '1') { throw 'Could not start an STA PowerShell session for the WinForms selector.' }
  $env:BUILDS_PS1_STA_RELAUNCH = '1'
  Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File', ('"' + $PSCommandPath + '"')) -Wait
  exit $LASTEXITCODE
}
$root = $PSScriptRoot; $buildDir = Join-Path $root '.pio\build'
function Get-Envs {
  $raw = & py -m platformio project config --json-output
  if ($LASTEXITCODE) { throw 'PlatformIO configuration lookup failed.' }
  $result = @()
  foreach ($item in ($raw | ConvertFrom-Json)) {
    $section = [string]$item[0]; if (-not $section.StartsWith('env:')) { continue }
    $cfg = @{}; foreach ($pair in $item[1]) { $cfg[[string]$pair[0]] = $pair[1] }
    $flags = if ($cfg.build_flags) { [string]::Join(' ', @($cfg.build_flags)) } else { '' }
    $text = "$flags $($cfg.platform) $($cfg.board)"
    $family = if ($text -match '(?i)NRF52_PLATFORM|nordicnrf52|nrf52|nrf528') { 'nRF52' } elseif ($text -match '(?i)ESP32_PLATFORM|espressif32|esp32') { 'ESP32' }
    if ($family) { $result += [PSCustomObject]@{ Name=$section.Substring(4); Family=$family } }
  }
  return $result | Sort-Object Name
}
Write-Host 'Discovering PlatformIO ESP32/nRF52 environments...' -ForegroundColor Cyan
$all = @(Get-Envs); if (!$all.Count) { throw 'No ESP32/nRF52 PlatformIO environments found.' }
Write-Host "Found $($all.Count) selectable environment(s)." -ForegroundColor Green
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
$form = New-Object Windows.Forms.Form -Property @{ Text='PlatformIO - Select Firmwares'; StartPosition='CenterScreen'; ClientSize=[Drawing.Size]::new(760,600); MinimumSize=[Drawing.Size]::new(620,440) }
$searchLabel = New-Object Windows.Forms.Label -Property @{ Dock='Top'; Text='Search build tags (LoRaFish, Heltec, companion_ble)'; AutoSize=$true; Padding=[Windows.Forms.Padding]::new(8,6,8,0) }
$search = New-Object Windows.Forms.TextBox -Property @{ Dock='Top' }
$buttons = New-Object Windows.Forms.FlowLayoutPanel -Property @{ Dock='Bottom'; AutoSize=$true; Padding=[Windows.Forms.Padding]::new(8) }
$panel = New-Object Windows.Forms.FlowLayoutPanel -Property @{ Dock='Fill'; AutoScroll=$true; FlowDirection='TopDown'; WrapContents=$false; Padding=[Windows.Forms.Padding]::new(8) }
$form.Controls.AddRange(@($panel,$buttons,$search,$searchLabel)); $boxes=@{}
foreach ($env in $all) { $cb=New-Object Windows.Forms.CheckBox -Property @{ Text="$($env.Name) [$($env.Family)]"; Tag=$env; AutoSize=$true; Font=[Drawing.Font]::new('Consolas',9) }; $panel.Controls.Add($cb); $boxes[$env.Name]=$cb }
$search.Add_TextChanged({ $term=$search.Text.Trim(); foreach($cb in $boxes.Values) { $cb.Visible=(!$term -or $cb.Tag.Name -match [regex]::Escape($term)) } })
function Add-Button($text,$action) { $b=New-Object Windows.Forms.Button -Property @{Text=$text; AutoSize=$true; Padding=[Windows.Forms.Padding]::new(8,3,8,3)}; $b.Add_Click($action); $buttons.Controls.Add($b); $b }
Add-Button 'Select Visible' { foreach($cb in $boxes.Values) { if($cb.Visible) {$cb.Checked=$true} } } | Out-Null
Add-Button 'Deselect All' { foreach($cb in $boxes.Values) {$cb.Checked=$false} } | Out-Null
$build=Add-Button 'Build Selected' {$form.DialogResult='OK';$form.Close()}; $build.BackColor=[Drawing.Color]::LightGreen
$cancel=Add-Button 'Cancel' {$form.DialogResult='Cancel';$form.Close()}; $form.AcceptButton=$build;$form.CancelButton=$cancel
if($form.ShowDialog() -ne 'OK'){Write-Host 'Cancelled.' -ForegroundColor Yellow;exit 0}
$selected=@($boxes.Values|Where-Object Checked|ForEach-Object Tag);if(!$selected.Count){Write-Host 'No firmwares selected.' -ForegroundColor Yellow;exit 0}
$failed=@(); foreach($family in 'ESP32','nRF52') { $batch=@($selected|Where-Object Family -eq $family);if(!$batch.Count){continue};Write-Host '';Write-Host "=== Building $family batch ($($batch.Count)) ===" -ForegroundColor Cyan;$args=@('-m','platformio','run');foreach($env in $batch){$args+=@('-e',$env.Name)};if($family -eq 'nRF52'){$args+=@('-t','create_uf2')};& py @args;if($LASTEXITCODE){$failed+=$batch.Name;Write-Host "[FAILED] $family batch" -ForegroundColor Red;continue};foreach($env in $batch){foreach($ext in 'bin','uf2'){$src=Join-Path (Join-Path $buildDir $env.Name) "firmware.$ext";if(Test-Path $src){Copy-Item $src (Join-Path $root "$($env.Name).$ext") -Force;Write-Host "Copied: $($env.Name).$ext" -ForegroundColor Green}}} }
Write-Host '';Write-Host '=== Done ===' -ForegroundColor Cyan;if($failed.Count){Write-Host "Failed: $($failed -join ', ')" -ForegroundColor Red;exit 1}

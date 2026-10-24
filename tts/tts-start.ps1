# Start the local Azure TTS shim used by `am video --voice local`.
# The subscription key is read from Windows Credential Manager at run time; this file holds no secret.
# Usage: powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.dsh\tts-start.ps1"
$ErrorActionPreference = "Stop"

$Port = 18321
$Shim = Join-Path $PSScriptRoot "tts-shim.mjs"
# Locate the DSH executable: DSH_EXE first, then the usual install locations.
# Nothing here assumes a user name or a drive letter.
$ExeCandidates = @()
if ($env:DSH_EXE) { $ExeCandidates += $env:DSH_EXE }
foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
  if ($root) { $ExeCandidates += (Join-Path $root "DeepSeek Harness\DeepSeek Harness.exe") }
}
if ($env:LOCALAPPDATA) {
  $ExeCandidates += (Join-Path $env:LOCALAPPDATA "Programs\DeepSeek Harness\DeepSeek Harness.exe")
}
$ExeCandidates += "D:\Program Files\DeepSeek Harness\DeepSeek Harness.exe"
$Exe = $null
foreach ($c in $ExeCandidates) {
  if ($c -and (Test-Path -LiteralPath $c)) { $Exe = $c; break }
}
if (-not $Exe) {
  throw "DeepSeek Harness.exe not found. Set DSH_EXE to its full path, then run this script again."
}
$Target = "TextToTalk_AccessKeys_AzureCognitiveServices"
$DefaultVoice = "zh-CN-Xiaoxiao:DragonHDFlashLatestNeural"

if (-not (Test-Path $Shim)) { throw "shim not found: $Shim" }
if (-not (Test-Path $Exe)) { throw "DSH executable not found: $Exe" }

$listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listening) {
  $existing = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 5).Content
  Write-Output "already running on port $Port (pid $($listening[0].OwningProcess)): $existing"
  exit 0
}

$signature = @'
using System;
using System.Runtime.InteropServices;
public class TtsCred {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CREDENTIAL {
    public int Flags; public int Type; public string TargetName; public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public int CredentialBlobSize; public IntPtr CredentialBlob;
    public int Persist; public int AttributeCount; public IntPtr Attributes;
    public string TargetAlias; public string UserName;
  }
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool CredRead(string target, int type, int flags, out IntPtr cred);
  [DllImport("advapi32.dll")]
  public static extern void CredFree(IntPtr cred);
}
'@
Add-Type -TypeDefinition $signature

$ptr = [IntPtr]::Zero
if (-not [TtsCred]::CredRead($Target, 1, 0, [ref]$ptr)) { throw "credential not found: $Target" }
$cred = [Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][TtsCred+CREDENTIAL])
$blob = New-Object byte[] $cred.CredentialBlobSize
[Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $blob, 0, $cred.CredentialBlobSize)
[TtsCred]::CredFree($ptr)

$script:envOk = $false
$env:AZREGION = $cred.UserName
$env:AZKEY = [System.Text.Encoding]::Unicode.GetString($blob).Trim()
if ($env:AZKEY) { $script:envOk = $true }
if (-not $script:envOk) { throw "credential blob is empty" }

$env:AZDEFAULTVOICE = $DefaultVoice
$env:ELECTRON_RUN_AS_NODE = "1"
$log = Join-Path $env:TEMP "tts-shim.log"
$err = Join-Path $env:TEMP "tts-shim.err.log"
$proc = Start-Process -FilePath $Exe -ArgumentList ('"' + $Shim + '"') -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError $err

$ok = $false
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 500
  try {
    $body = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 2).Content
    Write-Output "started (pid $($proc.Id)): $body"
    Write-Output "log: $log"
    $ok = $true
    break
  } catch { }
}
if (-not $ok) {
  Write-Output "shim did not answer on port $Port; see $log and $err"
  exit 1
}
exit 0

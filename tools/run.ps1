param([ValidateSet('web','test','test-full','build-web','quick-web','deploy-web','store-readiness','build-apk')][string]$Action='web', [string]$Version, [string[]]$TestFile, [string]$TestName, [switch]$Analyze)
$ErrorActionPreference='Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
# Keep native plugin source paths ASCII-only and on the project's drive.
$env:PUB_CACHE=Join-Path (Get-Location).Path '.pub-cache'
$taskJdk='C:\Program Files\Android\Android Studio1\jbr'
if (Test-Path -LiteralPath $taskJdk) {
  $env:JAVA_HOME=$taskJdk
  $env:PATH="$taskJdk\bin;$env:PATH"
}
function Invoke-QuickWeb {
  param([string[]]$ModeArgs = @())
  $quickArgs=@('tools/quick_web.py') + $ModeArgs
  if($Version){$quickArgs+=@('--version',$Version)}
  if($Analyze){$quickArgs+='--analyze'}
  foreach($file in $TestFile){$quickArgs+=@('--test',$file)}
  if($TestName){$quickArgs+=@('--test-name',$TestName)}
  python @quickArgs
}
switch ($Action) {
  'web' { python tools/sync_version.py; if ($LASTEXITCODE -eq 0) { flutter run -d chrome } }
  'test' { Invoke-QuickWeb -ModeArgs @('--checks-only') }
  'test-full' { Invoke-QuickWeb -ModeArgs @('--checks-only','--analyze','--test','test') }
  'build-web' { Invoke-QuickWeb -ModeArgs @('--build-only') }
  'quick-web' { Invoke-QuickWeb }
  'deploy-web' { Invoke-QuickWeb -ModeArgs @('--deploy') }
  'store-readiness' { python tools/google_play_readiness.py }
  'build-apk' { throw '사용자 지침: 게임 완성 전 APK 빌드 금지. 사용자의 명시적 변경 전에는 웹으로 검증하세요.' }
}
exit $LASTEXITCODE

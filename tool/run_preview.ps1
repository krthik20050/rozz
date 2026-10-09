$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
  flutter run -d windows --dart-define=ROZZ_DESKTOP_PREVIEW=true
  if ($LASTEXITCODE -ne 0) { throw 'Flutter preview failed. Run flutter doctor -v to check C++ tooling.' }
} finally {
  Pop-Location
}

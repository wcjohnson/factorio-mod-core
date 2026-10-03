param(
	[string]$LuaExecutable = "lua54"
)

$ErrorActionPreference = "Stop"
$lua = (Get-Command $LuaExecutable -CommandType Application -ErrorAction Stop).Source
$coreRoot = Split-Path -Parent $PSScriptRoot
$tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.lua" -File |
	Sort-Object Name)

if ($tests.Count -eq 0) {
	throw "No standalone Lua integration tests found in $PSScriptRoot"
}

$failed = 0
Push-Location -LiteralPath $coreRoot
try {
	foreach ($test in $tests) {
		Write-Host "`nRunning $($test.Name)"
		& $lua $test.FullName $coreRoot
		if ($LASTEXITCODE -ne 0) {
			$failed++
			Write-Host "FAIL $($test.Name) (exit code $LASTEXITCODE)"
		}
	}
}
finally {
	Pop-Location
}

Write-Host "`n$($tests.Count - $failed)/$($tests.Count) test files passed."
if ($failed -gt 0) {
	exit 1
}
exit 0

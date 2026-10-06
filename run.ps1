<#
.SYNOPSIS
    Runs the Robot Framework suite against the configured environment.

.DESCRIPTION
    A thin wrapper that activates the local virtual environment and forwards
    everything it is given to `robot`. It exists for one reason beyond
    convenience: some shells export PYTHONIOENCODING in a form Robot Framework
    cannot parse ("utf-8:surrogateescape"), which makes the run die before it
    starts. Pinning the variable here removes that failure mode.

.EXAMPLE
    .\run.ps1
    Runs every suite.

.EXAMPLE
    .\run.ps1 --include smoke
    Runs the smoke subset.

.EXAMPLE
    .\run.ps1 --variable HEADLESS:False tests/ui
    Watches the UI suites run in a visible browser.
#>

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$robot = Join-Path $root '.venv\Scripts\robot.exe'

if (-not (Test-Path $robot)) {
    Write-Error "No virtual environment found. Run: python -m venv .venv; .\.venv\Scripts\python.exe -m pip install -r requirements.txt; .\.venv\Scripts\rfbrowser.exe init chromium"
}

$env:PYTHONIOENCODING = 'utf-8'

$arguments = $args
if ($arguments.Count -eq 0) {
    $arguments = @('tests')
}

& $robot --outputdir results --name 'Beat The Stack' @arguments
exit $LASTEXITCODE

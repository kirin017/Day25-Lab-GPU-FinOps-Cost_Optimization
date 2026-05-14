param(
    [ValidateSet("start", "stop", "tunnel", "status", "logs", "test")]
    [string]$Command = "start",
    [string]$Service = ""
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TunnelPidFile = Join-Path $ProjectDir ".tunnel.pid"
$TunnelLogFile = Join-Path $ProjectDir ".tunnel.log"
$TunnelErrFile = Join-Path $ProjectDir ".tunnel.err.log"
$DockerContext = "desktop-linux"
$TryCloudflareUrlPattern = "https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com"

function Write-Step($Message) { Write-Host "`n[STEP] $Message" -ForegroundColor Green }
function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Yellow }
function Write-ErrorLine($Message) { Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Resolve-Executable($Name, $FallbackPaths = @()) {
    $Command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($Command) {
        return $Command.Source
    }
    foreach ($Path in $FallbackPaths) {
        if (Test-Path -LiteralPath $Path) {
            return $Path
        }
    }
    return $null
}

function Test-DockerReady {
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & docker --context $DockerContext info 1> $null 2> $null
    $ExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    return ($ExitCode -eq 0)
}

function Invoke-EndpointTest($Path) {
    $Url = "http://localhost:8000$Path"
    try {
        $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        if ($Response.StatusCode -eq 200) {
            Write-Host "  [OK] GET $Path" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL:$($Response.StatusCode)] GET $Path" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [FAIL] GET $Path - $($_.Exception.Message)" -ForegroundColor Red
    }
}

switch ($Command) {
    "start" {
        Write-Step "1/3 - Checking Docker..."
        if (-not (Test-DockerReady)) {
            Write-ErrorLine "Docker is not running. Start Docker Desktop first, then rerun this command."
            exit 1
        }
        Write-Host "  Docker is running"

        Write-Step "2/3 - Building and starting services..."
        Push-Location $ProjectDir
        try {
            docker --context $DockerContext compose up --build -d
        } finally {
            Pop-Location
        }

        Write-Step "3/3 - Waiting for services to be healthy..."
        Start-Sleep -Seconds 5

        try {
            Invoke-WebRequest -Uri "http://localhost:8000/" -UseBasicParsing -TimeoutSec 10 *> $null
            Write-Host "  Gateway is UP at http://localhost:8000" -ForegroundColor Green
        } catch {
            Write-ErrorLine "Gateway not responding. Check: .\run-windows.ps1 logs gateway"
            exit 1
        }

        Write-Host ""
        Write-Host "=========================================="
        Write-Host " ALL SERVICES RUNNING" -ForegroundColor Green
        Write-Host "=========================================="
        Write-Host ""
        Write-Host "  Gateway:          http://localhost:8000"
        Write-Host "  GPU Node Manager: http://localhost:8001"
        Write-Host "  Billing API:      http://localhost:8002"
        Write-Host "  Spot Manager:     http://localhost:8003"
        Write-Host "  Autoscaler:       http://localhost:8004"
        Write-Host "  Cost Tracker:     http://localhost:8005"
        Write-Host ""
        Write-Host "Next: Run '.\run-windows.ps1 tunnel' to expose to Kaggle/Colab"
    }

    "tunnel" {
        Write-Step "Starting tunnel to expose gateway..."

        $CloudflaredPath = Resolve-Executable "cloudflared" @(
            "C:\Program Files\cloudflared\cloudflared.exe",
            "C:\Program Files (x86)\cloudflared\cloudflared.exe"
        )
        $NgrokPath = Resolve-Executable "ngrok"

        if ($CloudflaredPath) {
            Write-Info "Using cloudflared (free, no account needed)"
            if (Test-Path $TunnelLogFile) { Remove-Item -LiteralPath $TunnelLogFile -Force }
            if (Test-Path $TunnelErrFile) { Remove-Item -LiteralPath $TunnelErrFile -Force }
            $Process = Start-Process -FilePath $CloudflaredPath `
                -ArgumentList @("tunnel", "--url", "http://localhost:8000") `
                -WorkingDirectory $ProjectDir `
                -RedirectStandardOutput $TunnelLogFile `
                -RedirectStandardError $TunnelErrFile `
                -PassThru `
                -WindowStyle Hidden
            Set-Content -Path $TunnelPidFile -Value $Process.Id

            $TunnelUrl = ""
            for ($i = 0; $i -lt 15; $i++) {
                Start-Sleep -Seconds 1
                if ((Test-Path $TunnelLogFile) -or (Test-Path $TunnelErrFile)) {
                    $Content = ""
                    if (Test-Path $TunnelLogFile) { $Content += Get-Content $TunnelLogFile -Raw -ErrorAction SilentlyContinue }
                    if (Test-Path $TunnelErrFile) { $Content += Get-Content $TunnelErrFile -Raw -ErrorAction SilentlyContinue }
                    $Match = [regex]::Match($Content, $TryCloudflareUrlPattern)
                    if ($Match.Success) {
                        $TunnelUrl = $Match.Value
                        break
                    }
                }
            }

            if ($TunnelUrl) {
                Write-Host ""
                Write-Host "=========================================="
                Write-Host " TUNNEL ACTIVE" -ForegroundColor Green
                Write-Host "=========================================="
                Write-Host ""
                Write-Host "  URL: $TunnelUrl" -ForegroundColor Green
                Write-Host ""
                Write-Host "  Copy this URL into your Kaggle/Colab notebook:"
                Write-Host "  GATEWAY_URL = `"$TunnelUrl`""
            } else {
                Write-Info "Tunnel is starting. Check .tunnel.log for the trycloudflare.com URL."
            }
        } elseif ($NgrokPath) {
            Write-Info "Using ngrok"
            $Process = Start-Process -FilePath $NgrokPath `
                -ArgumentList @("http", "8000") `
                -WorkingDirectory $ProjectDir `
                -PassThru `
                -WindowStyle Hidden
            Set-Content -Path $TunnelPidFile -Value $Process.Id
            Start-Sleep -Seconds 3
            $TunnelInfo = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -TimeoutSec 10
            $TunnelUrl = $TunnelInfo.tunnels[0].public_url
            Write-Host ""
            Write-Host "=========================================="
            Write-Host " TUNNEL ACTIVE" -ForegroundColor Green
            Write-Host "=========================================="
            Write-Host ""
            Write-Host "  URL: $TunnelUrl" -ForegroundColor Green
            Write-Host "  GATEWAY_URL = `"$TunnelUrl`""
        } else {
            Write-Info "No tunnel tool found. Install cloudflared or ngrok."
            Write-Host ""
            Write-Host "  cloudflared: winget install --id Cloudflare.cloudflared"
            Write-Host "  ngrok:       winget install --id Ngrok.Ngrok"
            exit 1
        }
    }

    "stop" {
        Write-Step "Stopping services..."
        Push-Location $ProjectDir
        try {
            docker --context $DockerContext compose down
        } finally {
            Pop-Location
        }

        if (Test-Path $TunnelPidFile) {
            $PidValue = Get-Content $TunnelPidFile -ErrorAction SilentlyContinue
            if ($PidValue) {
                Stop-Process -Id ([int]$PidValue) -Force -ErrorAction SilentlyContinue
            }
            Remove-Item -LiteralPath $TunnelPidFile -Force
            Write-Host "  Tunnel stopped"
        }
        Write-Host "  All stopped." -ForegroundColor Green
    }

    "status" {
        Write-Host "=== Docker Services ==="
        Push-Location $ProjectDir
        try {
            docker --context $DockerContext compose ps
        } finally {
            Pop-Location
        }

        Write-Host ""
        Write-Host "=== Gateway Health ==="
        try {
            Invoke-RestMethod -Uri "http://localhost:8000/" -TimeoutSec 10 | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "  Not running"
        }

        Write-Host ""
        Write-Host "=== Tunnel ==="
        if (Test-Path $TunnelPidFile) {
            $PidValue = Get-Content $TunnelPidFile -ErrorAction SilentlyContinue
            $Process = Get-Process -Id ([int]$PidValue) -ErrorAction SilentlyContinue
            if ($Process) {
                Write-Host "  Tunnel PID: $PidValue (running)"
                if ((Test-Path $TunnelLogFile) -or (Test-Path $TunnelErrFile)) {
                    $Content = ""
                    if (Test-Path $TunnelLogFile) { $Content += Get-Content $TunnelLogFile -Raw -ErrorAction SilentlyContinue }
                    if (Test-Path $TunnelErrFile) { $Content += Get-Content $TunnelErrFile -Raw -ErrorAction SilentlyContinue }
                    $Matches = [regex]::Matches($Content, $TryCloudflareUrlPattern)
                    if ($Matches.Count -gt 0) {
                        Write-Host "  $($Matches[$Matches.Count - 1].Value)"
                    }
                }
            } else {
                Write-Host "  No tunnel running"
            }
        } else {
            Write-Host "  No tunnel running"
        }
    }

    "logs" {
        Push-Location $ProjectDir
        try {
            if ($Service) {
                docker --context $DockerContext compose logs -f --tail=50 $Service
            } else {
                docker --context $DockerContext compose logs -f --tail=50
            }
        } finally {
            Pop-Location
        }
    }

    "test" {
        Write-Step "Testing all endpoints..."
        @(
            "/",
            "/cluster/nodes",
            "/cluster/metrics",
            "/billing/pricing",
            "/spot/pricing",
            "/autoscaler/policy",
            "/cost/dashboard"
        ) | ForEach-Object { Invoke-EndpointTest $_ }
    }
}

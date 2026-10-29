# DoECISORY - PowerShell Developer File Watcher Mode
# Monitors the src/ directory and restarts Julia upon changes.

$HOST_URL = "http://127.0.0.1:8060"
$PROJECT_DIR = (Get-Item $PSScriptRoot).Parent.FullName
$SOURCE_DIR = Join-Path $PROJECT_DIR "src"
$APP_FILE = Join-Path $PROJECT_DIR "app.jl"

$SYSIMG_DEPS_DLL = Join-Path $PSScriptRoot "Sysimage_Deps.dll"
$SYSIMG_DEPS_SO  = Join-Path $PSScriptRoot "Sysimage_Deps.so"
$SYSIMG_DEPS = $null
if (Test-Path $SYSIMG_DEPS_DLL) { $SYSIMG_DEPS = $SYSIMG_DEPS_DLL }
elseif (Test-Path $SYSIMG_DEPS_SO) { $SYSIMG_DEPS = $SYSIMG_DEPS_SO }

$env:DOECISORY_DEV = "true"
$env:DOECISORY_NO_BROWSER = "true"

$julia_proc = $null

function Write-Log {
    param(
        [string]$Source,
        [string]$Evt,
        [string]$Detail,
        [string]$Type = "INFO"
    )
    $ts = Get-Date -Format "HH:mm:ss.fff"
    
    $fg = "Blue"
    if ($Type -eq "OK") { $fg = "Green" }
    elseif ($Type -eq "WARN") { $fg = "Yellow" }
    elseif ($Type -eq "FAIL") { $fg = "Red" }
    elseif ($Type -eq "WAIT") { $fg = "Cyan" }

    Write-Host "[" -NoNewline -ForegroundColor Blue
    Write-Host "$ts" -NoNewline -ForegroundColor Blue
    Write-Host "] " -NoNewline -ForegroundColor Blue
    Write-Host "$($Source.PadRight(11))" -NoNewline -ForegroundColor Green
    Write-Host ": " -NoNewline
    Write-Host "$($Evt.PadRight(16)) " -NoNewline -ForegroundColor $fg
    Write-Host "$Detail" -ForegroundColor $fg
}

function Start-Julia {
    $julia_args = "--depwarn=no --threads auto -O1 --project=`"$PROJECT_DIR`" `"$APP_FILE`""
    if ($SYSIMG_DEPS) {
        $julia_args = "--sysimage=`"$SYSIMG_DEPS`" $julia_args"
    }
    $script:julia_proc = Start-Process -FilePath "julia" `
        -ArgumentList $julia_args `
        -RedirectStandardError "NUL" `
        -WorkingDirectory $PROJECT_DIR `
        -PassThru `
        -NoNewWindow
    return $script:julia_proc
}

function Get-SrcMtime {
    $files = Get-ChildItem -Path $SOURCE_DIR -Filter "*.jl" -Recurse
    $files += Get-Item -Path $APP_FILE
    return ($files | Measure-Object -Property LastWriteTime -Maximum).Maximum
}

$restart_count = 0
$uptime_seconds = 0
$last_mtime = Get-SrcMtime

try {
    if ($SYSIMG_DEPS) {
        Write-Log -Source "BOOT" -Evt "Image" -Detail "Sysimage_Deps active. Accelerated Watcher..." -Type "OK"
    } else {
        Write-Log -Source "BOOT" -Evt "Image" -Detail "No Sysimage_Deps found. JIT file watching..." -Type "WAIT"
    }
    Write-Log -Source "BOOT" -Evt "Setup" -Detail "Launching Julia background runtime..." -Type "OK"
    $julia_proc = Start-Julia

    # Wait until port 8060 is actively listening before opening browser
    $portReady = $false
    $waitTimeout = [DateTime]::Now.AddSeconds(90)
    while ([DateTime]::Now -lt $waitTimeout -and -not $portReady) {
        if ($julia_proc.HasExited) { break }
        Start-Sleep -Milliseconds 250
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $ar = $tcp.BeginConnect("127.0.0.1", 8060, $null, $null)
            if ($ar.AsyncWaitHandle.WaitOne(100, $false) -and $tcp.Connected) {
                try { $tcp.EndConnect($ar) } catch {}
                $portReady = $true
            }
            $tcp.Close()
        } catch {
            if ($tcp) { try { $tcp.Close() } catch {} }
        }
    }
    if ($portReady) {
        Write-Log -Source "SERVER" -Evt "Ready" -Detail "Port 8060 confirmed. Launching browser..." -Type "OK"
        try { Start-Process $HOST_URL } catch {}
    }

    while ($true) {
        Start-Sleep -Seconds 1
        
        # Check if process is still alive
        if ($julia_proc.HasExited) {
            $restart_count++
            if ($restart_count -gt 3) {
                Write-Log -Source "WATCHER" -Evt "Halt" -Detail "Exiting after 3 consecutive failures." -Type "FAIL"
                break
            }
            Write-Log -Source "WATCHER" -Evt "Restart" -Detail "Process terminated unexpectedly. Restarting ($restart_count/3)..." -Type "WARN"
            Start-Sleep -Seconds 2
            $env:DOECISORY_NO_BROWSER = "true"
            $julia_proc = Start-Julia
            $uptime_seconds = 0
            $last_mtime = Get-SrcMtime
            continue
        }

        # Julia is running; reset restart counter
        $uptime_seconds++
        if ($uptime_seconds -gt 15) {
            $restart_count = 0
        }

        $current_mtime = Get-SrcMtime
        if ($current_mtime -gt $last_mtime) {
            Write-Log -Source "WATCHER" -Evt "Reload" -Detail "Source modification detected. Restarting..." -Type "WARN"
            $last_mtime = $current_mtime

            # Stop Julia process
            try { Stop-Process -Id $julia_proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            Start-Sleep -Seconds 1

            # Clear the port
            try {
                Get-NetTCPConnection -LocalPort 8060 -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue |
                ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
            }
            catch {}

            Start-Sleep -Seconds 1
            $env:DOECISORY_NO_BROWSER = "true"
            $julia_proc = Start-Julia

            Write-Log -Source "WATCHER" -Evt "Complete" -Detail "Server recycled. Refresh browser (F5)." -Type "OK"
        }
    }
}
finally {
    Write-Log -Source "WATCHER" -Evt "Shutdown" -Detail "Terminating background processes and cleaning up..." -Type "WAIT"
    if ($julia_proc -and -not $julia_proc.HasExited) {
        try { Stop-Process -Id $julia_proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}


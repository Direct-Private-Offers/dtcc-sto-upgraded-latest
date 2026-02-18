# multi-repo-sync.ps1
# Sync all your DPO repositories across desktop/laptop
# Usage: .\multi-repo-sync.ps1

param(
    [string]$Message = "sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

$repos = @(
    "C:\Users\smitherman\dtcc-sto-upgraded-latest",
    "C:\Users\smitherman\DPO_AI_CRM_LEAD_MGMT"
    # Add your DTCC-Django repo path here:
    # "C:\Users\smitherman\dtcc-django-repo"
)

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🔄 Multi-Repo Sync Tool" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$currentDir = Get-Location
$successCount = 0
$failCount = 0

foreach ($repo in $repos) {
    if (Test-Path $repo) {
        Write-Host ""
        Write-Host "📂 Syncing: $repo" -ForegroundColor Yellow
        Write-Host "─────────────────────────────────────" -ForegroundColor Gray
        
        try {
            Set-Location $repo
            
            # Check if sync-repo.ps1 exists
            if (Test-Path ".\sync-repo.ps1") {
                & ".\sync-repo.ps1" -Message $Message
                $successCount++
            } else {
                Write-Host "⚠️  No sync-repo.ps1 found, using basic sync..." -ForegroundColor Yellow
                
                # Basic sync
                git add -A
                git commit -m $Message --no-verify 2>$null
                git fetch --all --prune
                git pull --rebase 2>$null
                git push 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Basic sync complete" -ForegroundColor Green
                    $successCount++
                } else {
                    Write-Host "⚠️  Some operations failed, check manually" -ForegroundColor Yellow
                    $failCount++
                }
            }
        } catch {
            Write-Host "❌ Error syncing $repo : $_" -ForegroundColor Red
            $failCount++
        }
    } else {
        Write-Host ""
        Write-Host "⚠️  Repo not found: $repo" -ForegroundColor Yellow
        $failCount++
    }
}

Set-Location $currentDir

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  📊 Sync Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅ Success: $successCount" -ForegroundColor Green
Write-Host "  ❌ Failed:  $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""

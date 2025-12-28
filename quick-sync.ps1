# quick-sync.ps1
# Quick launcher for sync-repo.ps1 from anywhere
# Add this to your PowerShell profile for instant access

$repoPath = "C:\Users\smitherman\dtcc-sto-upgraded-latest"

# Save current location
$currentLocation = Get-Location

try {
    # Navigate to repo
    Set-Location $repoPath
    
    # Run sync script
    & "$repoPath\sync-repo.ps1" @args
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
} finally {
    # Return to original location
    Set-Location $currentLocation
}

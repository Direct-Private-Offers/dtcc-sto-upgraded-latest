# repo-switcher.ps1
# Quick navigation between DPO repositories
# Usage: .\repo-switcher.ps1 [repo-number]

Write-Host ""
Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🚀 DPO Repository Switcher          ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$repos = @{
    1 = @{
        Name = "DTCC STO (Smart Contracts)"
        Path = "C:\Users\smitherman\dtcc-sto-upgraded-latest"
        Description = "Blockchain, Hardhat, Smart Contracts"
    }
    2 = @{
        Name = "CRM Lead Management"
        Path = "C:\Users\smitherman\DPO_AI_CRM_LEAD_MGMT"
        Description = "Notebooks, LangGraph, Integrations"
    }
    # Add your DTCC-Django repo:
    # 3 = @{
    #     Name = "DTCC Django Backend"
    #     Path = "C:\Users\smitherman\dtcc-django-backend"
    #     Description = "Django REST API, Event Ingestion"
    # }
}

# Display menu
foreach ($key in $repos.Keys | Sort-Object) {
    $repo = $repos[$key]
    $exists = Test-Path $repo.Path
    $status = if ($exists) { "✅" } else { "❌" }
    
    Write-Host "$status [$key] " -NoNewline -ForegroundColor $(if ($exists) { "Green" } else { "Red" })
    Write-Host "$($repo.Name)" -ForegroundColor White
    Write-Host "     📁 $($repo.Path)" -ForegroundColor Gray
    Write-Host "     💡 $($repo.Description)" -ForegroundColor DarkGray
    Write-Host ""
}

# Get user choice
$choice = Read-Host "Select repository (1-$($repos.Count)) or Q to quit"

if ($choice -eq 'Q' -or $choice -eq 'q') {
    Write-Host "👋 Goodbye!" -ForegroundColor Yellow
    exit
}

if ($repos.ContainsKey([int]$choice)) {
    $selected = $repos[[int]$choice]
    
    if (Test-Path $selected.Path) {
        Write-Host ""
        Write-Host "🚀 Switching to: $($selected.Name)" -ForegroundColor Green
        Set-Location $selected.Path
        
        # Show current branch
        $branch = git branch --show-current 2>$null
        if ($branch) {
            Write-Host "📍 Current branch: $branch" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "💡 Available commands:" -ForegroundColor Cyan
        Write-Host "  • .\sync-repo.ps1       - Sync this repo" -ForegroundColor Gray
        Write-Host "  • .\multi-repo-sync.ps1 - Sync all repos" -ForegroundColor Gray
        Write-Host "  • code .                - Open in VS Code" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "❌ Repository not found: $($selected.Path)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Invalid choice" -ForegroundColor Red
}

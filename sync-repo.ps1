# sync-repo.ps1
# Quick Git Sync Script for Desktop/Laptop Workflow
# Usage: .\sync-repo.ps1

param(
    [string]$Message = "sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🔄 Git Repository Sync Tool" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Get current branch
$currentBranch = git branch --show-current
Write-Host "📍 Current branch: " -NoNewline -ForegroundColor Yellow
Write-Host $currentBranch -ForegroundColor White

# Check if there are any changes
$status = git status --porcelain
if ($status) {
    Write-Host "📝 Uncommitted changes found" -ForegroundColor Yellow
    
    # Show what's changed
    Write-Host ""
    git status --short
    Write-Host ""
    
    # Ask user if they want to commit
    $commit = Read-Host "Commit these changes? (Y/n)"
    
    if ($commit -ne 'n' -and $commit -ne 'N') {
        Write-Host "💾 Staging all changes..." -ForegroundColor Green
        git add -A
        
        Write-Host "💾 Committing changes..." -ForegroundColor Green
        git commit -m $Message --no-verify
        
        Write-Host "✅ Changes committed!" -ForegroundColor Green
    } else {
        Write-Host "⏭️  Skipping commit" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Working directory clean" -ForegroundColor Green
}

Write-Host ""
Write-Host "🌐 Fetching from remote..." -ForegroundColor Cyan
git fetch --all --prune

Write-Host ""
Write-Host "⬇️  Pulling latest changes..." -ForegroundColor Cyan
$pullResult = git pull origin $currentBranch --rebase 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Pull successful!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Pull had issues:" -ForegroundColor Red
    Write-Host $pullResult
    Write-Host ""
    Write-Host "💡 You may need to resolve conflicts manually" -ForegroundColor Yellow
    exit 1
}

# Check if there's anything to push
$ahead = git rev-list --count origin/$currentBranch..$currentBranch 2>$null
if ($ahead -and $ahead -gt 0) {
    Write-Host ""
    Write-Host "⬆️  Pushing $ahead commit(s) to remote..." -ForegroundColor Cyan
    git push origin $currentBranch
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Push successful!" -ForegroundColor Green
    } else {
        Write-Host "❌ Push failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "✅ Already up to date with remote" -ForegroundColor Green
}

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✨ Sync Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Show recent commits
Write-Host "📜 Recent commits:" -ForegroundColor Yellow
git log -5 --oneline --decorate --color=always
Write-Host ""

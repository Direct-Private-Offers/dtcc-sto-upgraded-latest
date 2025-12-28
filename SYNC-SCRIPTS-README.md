# Git Sync Scripts - Setup Guide

## 📁 Files Created

1. **sync-repo.ps1** - Main sync script (run from repo directory)
2. **quick-sync.ps1** - Quick launcher (run from anywhere)

---

## 🚀 Quick Start

### Option 1: From Repo Directory
```powershell
cd C:\Users\smitherman\dtcc-sto-upgraded-latest
.\sync-repo.ps1
```

### Option 2: From Anywhere (After Setup)
```powershell
quick-sync
```

---

## ⚙️ One-Time Setup (Both Machines)

### Step 1: Add to PowerShell Profile

Run this once on each machine:

```powershell
# Open PowerShell profile
notepad $PROFILE

# If file doesn't exist, create it first:
New-Item -Path $PROFILE -Type File -Force
notepad $PROFILE
```

### Step 2: Add This to Profile

Copy and paste into your profile file:

```powershell
# Git Sync Shortcut
function quick-sync {
    $repoPath = "C:\Users\smitherman\dtcc-sto-upgraded-latest"
    $currentLocation = Get-Location
    
    try {
        Set-Location $repoPath
        & "$repoPath\sync-repo.ps1" @args
    } finally {
        Set-Location $currentLocation
    }
}
```

### Step 3: Reload Profile

```powershell
. $PROFILE
```

### Step 4: Test It

```powershell
quick-sync
```

---

## 🔧 For Laptop (Different Path)

If your laptop has a different path, update the function:

```powershell
# Laptop version - adjust path as needed
function quick-sync {
    $repoPath = "C:\Users\YOUR_LAPTOP_USERNAME\dtcc-sto-upgraded-latest"
    $currentLocation = Get-Location
    
    try {
        Set-Location $repoPath
        & "$repoPath\sync-repo.ps1" @args
    } finally {
        Set-Location $currentLocation
    }
}
```

---

## 📝 Usage Examples

### Basic Sync
```powershell
quick-sync
```

### Sync with Custom Message
```powershell
quick-sync -Message "feat: added new compliance checks"
```

### From Repo Directory
```powershell
.\sync-repo.ps1
.\sync-repo.ps1 -Message "fix: resolved merge conflicts"
```

---

## 🔄 Daily Workflow

### Morning (Start Work)
```powershell
quick-sync  # Pull latest changes
```

### Evening (End Work)
```powershell
quick-sync  # Commit and push your work
```

### Switching Machines
```powershell
# Desktop before leaving
quick-sync

# Laptop when you arrive
quick-sync
```

---

## 🛡️ What It Does

1. ✅ Shows current branch
2. ✅ Detects uncommitted changes
3. ✅ Asks if you want to commit
4. ✅ Stages all changes
5. ✅ Commits with timestamp
6. ✅ Fetches from remote
7. ✅ Pulls with rebase
8. ✅ Pushes to remote
9. ✅ Shows recent commits

---

## 🚨 Troubleshooting

### "Execution Policy" Error

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Cannot find path" Error

Update the path in your profile to match your machine.

### Merge Conflicts

The script will stop and alert you. Resolve conflicts manually:

```powershell
git status
# Fix conflicts in files
git add .
git rebase --continue
git push
```

---

## 💡 Pro Tips

1. **Run before closing laptop**: `quick-sync`
2. **Run when opening laptop**: `quick-sync`
3. **Crashes**: Your work is auto-committed with timestamps
4. **Multiple branches**: Script works on whatever branch you're on

---

## 🔐 Security Note

- Script uses your existing git credentials
- Commits are signed with your configured git user
- All changes go through branch protection rules

---

**Happy syncing! 🎉**

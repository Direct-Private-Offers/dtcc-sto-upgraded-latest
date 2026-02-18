# Multi-Repository Laptop/Desktop Sync Setup

## 📂 Your DPO Repositories

1. **dtcc-sto-upgraded-latest** - Smart Contracts & Blockchain
2. **DPO_AI_CRM_LEAD_MGMT** - CRM with Notebooks (DTCC-Django MVP, Large Institutional)
3. **[Your DTCC-Django Repo]** - Django Backend

---

## 🚀 Quick Setup (One-Time)

### Step 1: Copy Sync Scripts to All Repos

```powershell
# Current repo already has scripts, copy to others:

# Copy to CRM repo
Copy-Item .\sync-repo.ps1 ..\DPO_AI_CRM_LEAD_MGMT\
Copy-Item .\multi-repo-sync.ps1 ..\DPO_AI_CRM_LEAD_MGMT\
Copy-Item .\repo-switcher.ps1 ..\DPO_AI_CRM_LEAD_MGMT\

# Copy to DTCC-Django repo (adjust path as needed)
# Copy-Item .\sync-repo.ps1 ..\dtcc-django-backend\
# Copy-Item .\multi-repo-sync.ps1 ..\dtcc-django-backend\
```

### Step 2: Update multi-repo-sync.ps1

Edit `multi-repo-sync.ps1` in each repo and add your DTCC-Django repo path:

```powershell
$repos = @(
    "C:\Users\smitherman\dtcc-sto-upgraded-latest",
    "C:\Users\smitherman\DPO_AI_CRM_LEAD_MGMT",
    "C:\Users\smitherman\YOUR-DTCC-DJANGO-REPO"  # <-- Add this
)
```

### Step 3: Add to PowerShell Profile

```powershell
# Open profile
notepad $PROFILE

# Add these functions:
function sync-all {
    C:\Users\smitherman\dtcc-sto-upgraded-latest\multi-repo-sync.ps1 @args
}

function switch-repo {
    C:\Users\smitherman\dtcc-sto-upgraded-latest\repo-switcher.ps1
}

# Save and reload
. $PROFILE
```

---

## 💻 Daily Workflow

### Morning (Start Work)

```powershell
# Sync all repos from remote
sync-all
```

### During Work

```powershell
# Switch between repos
switch-repo

# Or navigate manually and sync one repo
cd dtcc-sto-upgraded-latest
.\sync-repo.ps1

cd ..\DPO_AI_CRM_LEAD_MGMT
.\sync-repo.ps1
```

### Evening (End Work)

```powershell
# Sync all repos to remote
sync-all
```

### Switching Machines

**Desktop before leaving**:
```powershell
sync-all  # Push all work to GitHub
```

**Laptop when starting**:
```powershell
sync-all  # Pull latest from all repos
```

---

## 📓 Notebook-Specific Workflow

### Working on CRM Notebooks

```powershell
# Navigate to CRM repo
switch-repo
# Select option 2

# Open notebooks
code notebooks/

# After editing
.\sync-repo.ps1
```

### Working on DTCC-Django MVP

```powershell
# If notebook is in CRM repo
cd DPO_AI_CRM_LEAD_MGMT
code notebooks/dtcc-django-mvp.ipynb

# Or if in separate repo
cd dtcc-django-backend
code notebooks/
```

---

## 🎯 Quick Commands Reference

| Command | What It Does |
|---------|-------------|
| `sync-all` | Sync all repos (commit, pull, push) |
| `switch-repo` | Interactive repo switcher |
| `.\sync-repo.ps1` | Sync current repo only |
| `quick-sync` | (If in profile) Sync from anywhere |

---

## 📂 Recommended Folder Structure

```
C:\Users\smitherman\
├── dtcc-sto-upgraded-latest/         # Smart contracts
│   ├── contracts/
│   ├── scripts/
│   ├── sync-repo.ps1 ✅
│   └── multi-repo-sync.ps1 ✅
│
├── DPO_AI_CRM_LEAD_MGMT/             # CRM + Notebooks
│   ├── notebooks/
│   │   ├── dtcc-django-mvp.ipynb
│   │   └── large-institutional.ipynb
│   ├── sync-repo.ps1 ✅
│   └── multi-repo-sync.ps1 ✅
│
└── dtcc-django-backend/              # Django API
    ├── backend/
    ├── notebooks/ (optional)
    ├── sync-repo.ps1 ✅
    └── multi-repo-sync.ps1 ✅
```

---

## 🔍 Finding Your DTCC-Django Repo

If you're not sure where your DTCC-Django repo is:

```powershell
# Search for Django projects
Get-ChildItem C:\Users\smitherman\ -Recurse -Filter "manage.py" -ErrorAction SilentlyContinue | Select-Object Directory

# Or search for typical Django folders
Get-ChildItem C:\Users\smitherman\ -Directory -Filter "*django*" -Recurse -Depth 2
```

---

## 🛠️ Troubleshooting

### "Repo not found"
- Update paths in `multi-repo-sync.ps1`
- Use absolute paths, not relative

### "Script not found"
- Copy sync scripts to all repos
- Check you're in the right directory

### Merge Conflicts
- Sync script will alert you
- Resolve manually, then run again

---

## ✅ Setup Checklist

- [ ] Copy sync scripts to all repos
- [ ] Update repo paths in multi-repo-sync.ps1
- [ ] Add functions to PowerShell profile
- [ ] Test sync-all command
- [ ] Test switch-repo command
- [ ] Verify notebooks are syncing

---

**Ready to sync! 🚀**

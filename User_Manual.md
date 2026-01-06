# **REPO-CRAFTER USER MANUAL**

**Version**: 1.0 (Generic Platform Edition)  
**Purpose**: Safe, interactive Git repository management for solo developers

---

## **📋 Table of Contents**

1. [Quick Start (5-Minute Setup)](#quick-start)
2. [Initial Configuration](#initial-configuration)
3. [Core Concepts](#core-concepts)
4. [Workflow Guides](#workflow-guides)
5. [Command-Line Options](#command-line-options)
6. [Troubleshooting](#troubleshooting)
7. [Safety Features](#safety-features)

---

## **1. Quick Start (5-Minute Setup)**

### **Step 1: Install Dependencies**

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y git curl jq openssh-client

# macOS (with Homebrew)
brew install git curl jq

# Fedora
sudo dnf install -y git curl jq openssh-clients

# Verify installation
for cmd in git curl jq ssh; do command -v "$cmd" && echo "✓ $cmd installed"; done
```

### **Step 2: Configure SSH Keys**

**For GitHub:**
```bash
# Generate key (if you don't have one)
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_github

# Add to GitHub
cat ~/.ssh/id_ed25519_github.pub

# Copy output and paste at: https://github.com/settings/keys
# Click "New SSH Key"

# Test connection
ssh -T git@github.com
# Expected: "Hi username! You've successfully authenticated..."
```

**For GitLab:**
```bash
# Generate key
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_gitlab

# Add to GitLab
cat ~/.ssh/id_ed25519_gitlab.pub

# Copy output and paste at: https://gitlab.com/-/profile/keys

# Test connection
ssh -T git@gitlab.com
# Expected: "Welcome to GitLab, @username!"
```

### **Step 3: Get API Tokens**

**GitHub Token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Scopes: Select `repo` (full repository access)
4. Expiration: Choose 90 days or custom
5. Click "Generate token"
6. **Copy the token immediately** (starts with `ghp_`)

**GitLab Token:**
1. Go to https://gitlab.com/-/profile/personal_access_tokens
2. Name: `repo-crafter`
3. Expiration: Choose date
4. Scopes: Select `api` (full API access)
5. Click "Create personal access token"
6. **Copy the token immediately** (starts with `glpat-`)

### **Step 4: Create `platforms.conf`**

Create the config file:
```bash
mkdir -p ~/.config/repo-crafter
nano ~/.config/repo-crafter/platforms.conf
```

Paste this template and save:

```ini
[github]
enabled = true
api_base = https://api.github.com
ssh_host = github.com
repo_domain = github.com
token_var = GITHUB_API_TOKEN
repo_check_endpoint = /repos/{owner}/{repo}
repo_check_method = GET
repo_check_success_key = id
repo_create_endpoint = /user/repos
repo_create_method = POST
repo_list_endpoint = /user/repos?per_page=100&sort=updated
repo_list_success_key = .[0].id
work_dir = github.com

[gitlab]
enabled = true
api_base = https://gitlab.com/api/v4
ssh_host = gitlab.com
repo_domain = gitlab.com
token_var = GITLAB_API_TOKEN
repo_check_endpoint = /projects/{owner}%2F{repo}
repo_check_method = GET
repo_check_success_key = id
repo_create_endpoint = /projects
repo_create_method = POST
repo_list_endpoint = /projects?membership=true&per_page=100&order_by=updated_at
repo_list_success_key = .[0].id
work_dir = gitlab.com

[multi]
work_dir = Multi-server
```

### **Step 5: Set Environment Variables**

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```bash
# GitHub token
export GITHUB_API_TOKEN="ghp_your_token_here"

# GitLab token
export GITLAB_API_TOKEN="glpat_your_token_here"
```

Apply changes:
```bash
source ~/.bashrc  # or ~/.zshrc
```

### **Step 6: Download repo-crafter**

```bash
# Place it in your PATH
mkdir -p ~/.local/bin
cd ~/.local/bin
wget https://raw.githubusercontent.com/yourusername/repo-crafter/main/repo-crafter.sh
chmod +x repo-crafter.sh

# Add to PATH if not already there
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## **2. Initial Configuration**

### **Verify Setup**

```bash
# Run configuration test
repo-crafter --test
```

**Expected output:**
```
Loading platform configuration... ✅ Loaded 2 platform(s): github gitlab

=== TESTING PLATFORM CONFIGURATION ===
Available platforms: github gitlab

Token status:
  github: ✓ Token set
  gitlab: ✓ Token set

Testing SSH connection to github.com... ✅ Connected
Testing SSH connection to gitlab.com... ✅ Connected

Testing platform selection...

Choose platform(s):
  1) github
  2) gitlab
  a) All platforms
  m) Multiple selection (e.g., 1,3,5)
  x) Cancel

Enter your choice: x

No selection made

Press Enter to continue...
```

If you see ✓ and ✅, your setup is correct.

---

## **3. Core Concepts**

### **Project Types**

**Local Projects** (`~/Projects/Local_Projects/`):  
- Completely disconnected from remotes
- For prototypes, trade secrets, offline work
- No push/pull capability

**Remote Projects** (`~/Projects/Remote_Projects/`):  
- Bound to GitHub/GitLab
- Can push/pull
- Organized by platform name

**Multi-Server Projects** (`~/Projects/Remote_Projects/Multi-server/`):  
- Pushed to multiple platforms simultaneously
- Creates `PLATFORMS.md` manifest

---

## **4. Workflow Guides**

### **Workflow 1: Create Your First Repository**

**Perfect for**: Starting a new hardware/embedded project

```bash
repo-crafter
```

**Menu Navigation**:
1. Select `1) 🆕 Create New Project`
2. Select `1) Create new local + remote repo (API)`
3. Enter project name: `motor-controller`
4. Select platform: `1` (GitHub) or `a` (All platforms)
5. Select visibility: `1` (Private)
6. Gitignore setup:
   - Choose `1) Simple` or `2) Cautious`
   - Enter patterns: `*.o`, `build/`, `*.hex`, `.vscode/`
   - Press Enter on empty line to finish
7. Confirm preview prompts with `y`

**Result**: New repository created, pushed, ready for development

---

### **Workflow 2: Clone an Existing Repository**

**Perfect for**: Joining an open-source project or team repo

```bash
repo-crafter
```

**Menu Navigation**:
1. Select `1) 🆕 Create New Project`
2. Select `2) Clone existing remote repo`
3. Select platform (e.g., GitHub)
4. Enter repository path: `organization/project-name` or `username/repo-name`
5. Repository clones to `~/Projects/Remote_Projects/github.com/project-name/`

---

### **Workflow 3: Work on Trade Secrets Offline**

**Perfect for**: Prototypes you don't want to push yet

```bash
repo-starter
```

**Menu Navigation**:
1. Select `1) 🆕 Create New Project`
2. Select `3) Create local-only project (no binding)`
3. Enter project name: `secret-sensor-design`
4. Work completely offline

**When ready to share:**
```bash
repo-starter
# Select: 2) 🔗 Convert Local → Remote
# Choose: secret-sensor-design
# Add platform(s) and push
```

---

### **Workflow 4: Archive a Project (Disconnect)**

**Perfect for**: Leaving company, archiving old work

```bash
repo-crafter
```

**Menu Navigation**:
1. Select `3) 🔓 Convert Remote → Local`
2. Choose project from list
3. Confirm preview → Project moved to `Local_Projects/`, remotes removed

**Result**: Keep all code locally, no remote sync, safe for personal backup

---

### **Workflow 5: Clean Up Disk Space**

**Perfect for**: Deleting old projects

```bash
repo-crafter
```

**Menu Navigation**:
1. Select `4) 🗑️ Manage/Delete Project`
2. Choose option:
   - `1) Delete local copy` (keeps remote)
   - `2) Unbind from remote` (keeps local)
   - `3) Delete BOTH` (irreversible!)
3. Follow confirmation prompts

**⚠️ DANGER**: Option 3 **permanently deletes** remote repository and local files

---

### **Workflow 6: List All Your Repositories**

**Perfect for**: Finding a project across platforms

```bash
repo-crafter
```

**Menu Navigation**:
1. Select `5) 📋 List Remote Repositories`
2. Select platform(s): `a` (All) or specific platform
3. Shows up to 20 repositories per platform

---

## **5. Command-Line Options**

### **Standalone Tests**

```bash
# Verify configuration without launching menu
repo-crafter --test
# or
repo-crafter -t
```

**Use when**: You changed tokens or SSH keys and want quick validation

### **Dry-Run Mode**

```bash
# Preview all operations without executing
repo-crafter --dry-run
# or
repo-crafter -n
```

**Use when**: Learning the tool, testing a new workflow, verifying multi-platform setup

**What happens**:
- Every command shows `[DRY RUN]` instead of executing
- After each workflow, press Enter to return to menu
- No files created, no API calls made

### **Help**

```bash
repo-crafter --help
# or
repo-crafter -h
```

---

## **6. Troubleshooting**

### **Problem: "Token NOT set" Error**

**Cause**: Environment variable not loaded

**Solution**:
```bash
# Check if variable exists
echo $GITHUB_API_TOKEN

# If empty, reload your profile
source ~/.bashrc

# Or set manually for current session
export GITHUB_API_TOKEN="ghp_xxxxxxxxxxxx"
```

### **Problem: SSH Connection Fails**

**Cause**: SSH key not added to platform or wrong key

**Solution**:
```bash
# Test manually
ssh -T git@github.com

# If fails, check key exists
ls ~/.ssh/id_ed25519_github*

# If missing, regenerate
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_github

# Add to GitHub again
cat ~/.ssh/id_ed25519_github.pub
# Copy to https://github.com/settings/keys
```

### **Problem: "Repository already exists" Warning**

**Cause**: You have another local project with same name

**Solution**:
- Use a different project name, OR
- Delete the old project first, OR
- Use `y` to continue anyway and manage duplicates manually

### **Problem: Push Fails with 403**

**Cause**: Token lacks correct permissions or you're not owner

**Solution**:
1. Regenerate token with `repo` scope (GitHub) or `api` scope (GitLab)
2. If it's an org repo, ensure you're a collaborator with push access
3. Verify remote URL is correct: `git remote -v`

### **Problem: "command not found: repo-crafter"**

**Cause**: Script not in PATH

**Solution**:
```bash
# Add to PATH permanently
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Test
which repo-crafter
```

---

## **7. Safety Features**

### **Automatic Protections**

- **Cannot operate in**: `/etc`, `/root`, `/bin`, `/sbin`, `/usr`, `/`
- **Directory checks**: Warns if project with same name exists elsewhere
- **Duplicate detection**: Shows similar remote repo names before creation
- **Confirmation required**: All destructive operations need explicit `y` input

### **Manual Safeguards**

- **Use `--dry-run`** before unfamiliar workflows
- **Use `--test`** after modifying `platforms.conf`
- **Never share tokens**; keep them in environment variables only
- **For critical work**: Maintain separate backup on different platform

---

## **8. Advanced Configuration**

### **Add a New Platform (e.g., Codeberg)**

Edit `~/.config/repo-crafter/platforms.conf`:

```ini
[codeberg]
enabled = true
api_base = https://codeberg.org/api/v1
ssh_host = codeberg.org
repo_domain = codeberg.org
token_var = CODEBERG_API_TOKEN
repo_check_endpoint = /repos/{owner}/{repo}
repo_check_method = GET
repo_check_success_key = id
repo_create_endpoint = /user/repos
repo_create_method = POST
repo_list_endpoint = /user/repos
repo_list_success_key = .[0].id
work_dir = codeberg.org
```

Set token:
```bash
export CODEBERG_API_TOKEN="your_codeberg_token"
```

Test:
```bash
repo-crafter --test
```

---

## **9. Best Practices for Indie Developers**

1. **Start local**: Use "Create local-only" for prototypes
2. **Push when ready**: Convert to remote when collaboration is needed
3. **Use Mode 3 gitignore**: For private notes, keys, experiments
4. **Multi-platform early**: If you might mirror to GitLab later, create as multi-server from start
5. **Clean up regularly**: Use `--dry-run` before deletion

---

## **10. File Locations Reference**

| File | Purpose | Back Up? |
|------|---------|----------|
| `~/.config/repo-crafter/platforms.conf` | Platform definitions | ✅ Yes |
| `~/.ssh/id_ed25519_github` | SSH private key | ✅ **CRITICAL** |
| `~/.ssh/id_ed25519_gitlab` | SSH private key | ✅ **CRITICAL** |
| `~/.bashrc` or `~/.zshrc` | Token environment variables | ✅ Yes |
| `~/Projects/` | All your projects | ✅ **CRITICAL** |

---

**Version**: 1.0 - Generic Platform Edition  
**License**: Use freely, modify as needed  
**Support**: File issues at your repository tracker

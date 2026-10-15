# Part 1 — Push the eLearning Site to GitHub

**Goal:** Put the eLearning static website, plus the files CodeBuild and CodeDeploy need, into a new GitHub repository.

**Lab flow:** **GitHub** → CodeBuild → S3 (artifact) → CodeDeploy → EC2 (Apache)

```
elearning-cicd/                 <- repository root
├── index.html, about.html, ... <- the website
├── css/  img/  js/  lib/
├── buildspec.yml               <- instructions for CodeBuild   (you create this)
├── appspec.yml                 <- instructions for CodeDeploy  (you create this)
├── scripts/                    <- lifecycle hook scripts       (you create this)
│   ├── install_dependencies.sh
│   ├── start_server.sh
│   └── validate_service.sh
├── .gitattributes              <- forces Linux line endings    (you create this)
└── hosting/                    <- these lab guides (not deployed)
```

---

## Prerequisites

- A GitHub account
- Git installed (`git --version`). On Windows, use **Git Bash** for the commands in this guide.
- VS Code or another editor

---

## Step 1 — Clone the starter project

### 1.1 Clone the repository

Clone the starter code into a new folder called `Week2Day3CodeDeployDemo` on your Desktop:

```bash
# Git Bash (Windows) or a terminal on Mac/Linux
cd ~/Desktop
git clone https://github.com/Nahashon-Kimani/Week2Day3CodeDeployDemo.git elearning-cicd
cd elearning-cicd
ls
```

You should see `index.html`, `css/`, `img/`, `js/`, `lib/` and `hosting/`.

### 1.2 Delete the `.git` folder

The clone still holds the instructor's Git history, and its `origin` points to the instructor's repository, which you can't push to. You'll be publishing this code to **your own** repository, so remove the existing `.git` folder and start fresh in Step 4.

> **Note:** `.git` is a hidden folder, so plain `ls` and File Explorer won't show it by default. Use `ls -a` to see it.

**Git Bash (Windows) or a terminal on Mac/Linux:**

```bash
# Make sure you are inside elearning-cicd before running this
pwd
rm -rf .git
```

**PowerShell (Windows):**

```powershell
Remove-Item -Recurse -Force .git
```

Confirm it is gone:

```bash
ls -a          # .git should no longer be listed
git status     # should print: fatal: not a git repository
```

> ⚠️ Run the delete command **only inside `Week2Day3CodeDeployDemo`**. Running `rm -rf .git` in the wrong folder wipes that project's Git history.

Do not continue to Step 2 until `git status` reports *not a git repository*.

---

## Step 2 — Create the repository on GitHub

1. Go to <https://github.com> and click **+** (top right) → **New repository**.
2. **Repository name:** `elearning-cicd`
3. **Visibility:** Public or Private. Both work with CodeBuild.
4. **Leave these unticked:** *Add a README*, *.gitignore* and *license*. The repo has to start empty so the first push doesn't conflict.
5. Click **Create repository**.
6. Copy the HTTPS URL, for example `https://github.com/<your-username>/elearning-cicd.git`.

---

## Step 3 — Add the deployment files

Create these files in the project root (`elearning-cicd/`). The CodeBuild and CodeDeploy guides explain each one in detail.

### 3.1 `.gitattributes`

On Windows, editors save files with CRLF (`\r\n`) line endings. A bash script with CRLF endings fails on Linux with `/bin/bash^M: bad interpreter`. This file tells Git to always store these files with LF endings:

```gitattributes
*.sh   text eol=lf
*.yml  text eol=lf
*.yaml text eol=lf
```

### 3.2 `buildspec.yml` (used by CodeBuild)

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Validating project structure..."
      - test -f index.html
      - test -f appspec.yml
      - test -d scripts
  build:
    commands:
      - echo "Build started on $(date)"
      # Safety net: strip Windows line endings and make the scripts executable
      - sed -i 's/\r$//' scripts/*.sh
      - chmod +x scripts/*.sh
      # Stamp the build so we can see which commit is live on the server
      - echo "Build ID  $CODEBUILD_BUILD_ID"                 >  build-info.txt
      - echo "Commit    $CODEBUILD_RESOLVED_SOURCE_VERSION"  >> build-info.txt
      - echo "Built at  $(date)"                             >> build-info.txt
  post_build:
    commands:
      - echo "Build completed on $(date)"

artifacts:
  files:
    - '**/*'
  exclude-paths:
    - '.git/**/*'
    - 'hosting/**/*'
    - 'buildspec.yml'
    - '.gitattributes'
```

### 3.3 `appspec.yml` (used by CodeDeploy)

```yaml
version: 0.0
os: linux

files:
  - source: /
    destination: /var/www/html

file_exists_behavior: OVERWRITE

hooks:
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: root
  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
      runas: root
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 120
      runas: root
```

### 3.4 `scripts/install_dependencies.sh`

```bash
#!/bin/bash
set -e
# Install Apache if it is not already installed (Amazon Linux 2023 uses dnf)
if ! rpm -q httpd > /dev/null 2>&1; then
  dnf install -y httpd
fi
```

### 3.5 `scripts/start_server.sh`

```bash
#!/bin/bash
set -e
systemctl enable httpd
systemctl restart httpd
```

### 3.6 `scripts/validate_service.sh`

```bash
#!/bin/bash
# Fail the deployment if the home page is not served
sleep 5
curl -sf http://localhost/index.html > /dev/null
```

> **VS Code tip:** before saving each `.sh` file, check the bottom-right status bar. If it shows `CRLF`, click it and switch to `LF`.

---

## Step 4 — Initialise Git and make the first commit

```bash
# One-time setup (skip if you've already done this)
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

# Initialise the repository on a 'main' branch
git init -b main

# Stage everything
git add .

# Mark the scripts as executable in Git. Windows can't set this bit on its own,
# and without it CodeDeploy fails with "Permission denied".
git update-index --chmod=+x scripts/install_dependencies.sh scripts/start_server.sh scripts/validate_service.sh

# Review what will be committed
git status

# Commit
git commit -m "Initial commit: eLearning site with CodeBuild and CodeDeploy config"
```

Check that the executable bit was recorded:

```bash
git ls-files -s scripts/
# Each line should start with 100755 (executable), not 100644
```

---

## Step 5 — Push to GitHub

```bash
git remote add origin https://github.com/<your-username>/elearning-cicd.git
git remote -v            # confirm the URL
git push -u origin main
```

**Authentication:**
- **Windows (Git for Windows):** Git Credential Manager opens a browser window. Sign in to GitHub and authorise.
- **Mac/Linux:** when asked for a password, paste a **Personal Access Token**, not your GitHub password. To create one: GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**. Give it access to this repo with **Contents: Read and write**.

---

## Step 6 — Verify

1. Refresh the repository page on GitHub.
2. Confirm you can see `index.html`, `buildspec.yml` and `appspec.yml` in the root, plus the `scripts/` folder.
3. Open `scripts/start_server.sh` on GitHub. It should display normally, with no `^M` characters.

✅ **Done.** Next: [2-codebuild.md](2-codebuild.md)

---

## Everyday Git workflow (for later in the lab)

```bash
# edit files...
git add .
git commit -m "Describe the change"
git push
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `remote origin already exists` | `git remote set-url origin <correct-url>` |
| `rejected ... fetch first` | You created the repo with a README. Run `git pull origin main --rebase`, then push again. |
| `Authentication failed` | Use a Personal Access Token instead of your password, or clear old credentials in Windows **Credential Manager**. |
| `src refspec main does not match any` | You haven't committed yet. Run `git commit` first. |
| `git init` says *Reinitialized existing Git repository* | The cloned `.git` folder wasn't deleted. Go back to Step 1.2. |
| Push goes to `Nahashon-Kimani/Week2Day3CodeDeployDemo` or is denied with 403 | Same cause: the old `origin` is still there. Delete `.git` (Step 1.2) and redo Steps 4–5. |

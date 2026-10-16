# Part 1 — Push the eLearning Site to GitHub

**Goal:** Put the eLearning static website, plus the files CodeBuild and CodeDeploy need, into a new GitHub repository.

**Lab flow:** **GitHub** → CodeBuild → S3 (artifact) → CodeDeploy → EC2 (Apache)

```
elearning-cicd/                 <- repository root
├── index.html, about.html, ... <- the website
├── css/  img/  js/  lib/
├── buildspec.yml               <- instructions for CodeBuild   (included)
├── appspec.yml                 <- instructions for CodeDeploy  (included)
├── scripts/                    <- lifecycle hook scripts       (included)
│   ├── install_dependencies.sh
│   ├── start_server.sh
│   └── validate_service.sh
├── .gitattributes              <- forces Linux line endings    (you create this)
├── hosting/                    <- these lab guides (not deployed)
└── codepipeline/               <- guides for the CodePipeline lab (not deployed)
```

---

## Prerequisites

- A GitHub account
- Git installed (`git --version`). On Windows, use **Git Bash** for the commands in this guide.
- VS Code or another editor

---

## Step 1 — Clone the starter project

### 1.1 Clone the repository

Clone the starter code into a new folder called `elearning-cicd` on your Desktop:

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

> ⚠️ Run the delete command **only inside `elearning-cicd`**. Running `rm -rf .git` in the wrong folder wipes that project's Git history.

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

## Step 3 — Review the deployment files

The project you cloned already contains the files CodeBuild and CodeDeploy need. You only have to create one file, `.gitattributes`.

### 3.1 Look at the included files

Open each of these in VS Code and read through it. The CodeBuild and CodeDeploy guides explain them in detail.

| File | Used by | What it does |
|---|---|---|
| `buildspec.yml` | CodeBuild | Checks that `index.html`, `appspec.yml` and `scripts/` exist; strips Windows line endings from the scripts and makes them executable; writes `build-info.txt` with the build ID and commit; lists which files go into the artifact (everything except `.git/`, the `hosting/` and `codepipeline/` guides, and the build config) |
| `appspec.yml` | CodeDeploy | Copies the files to `/var/www/html` and runs the three scripts below at the right lifecycle events |
| `scripts/install_dependencies.sh` | CodeDeploy (`BeforeInstall`) | Installs Apache (`httpd`) if it isn't already installed |
| `scripts/start_server.sh` | CodeDeploy (`ApplicationStart`) | Enables and restarts Apache |
| `scripts/validate_service.sh` | CodeDeploy (`ValidateService`) | Requests the home page with `curl`; the deployment fails if it isn't served |

> **VS Code tip:** with a `.sh` file open, check the bottom-right status bar. If it shows `CRLF`, click it, switch to `LF` and save. Scripts with Windows line endings fail on Linux with `/bin/bash^M: bad interpreter`.

### 3.2 Create `.gitattributes`

On Windows, Git and editors can convert files to CRLF (`\r\n`) line endings. This file tells Git to always store scripts and YAML files with Linux (LF) line endings.

Create a file named `.gitattributes` (note the leading dot) in the project root, containing:

```gitattributes
*.sh   text eol=lf
*.yml  text eol=lf
*.yaml text eol=lf
```

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

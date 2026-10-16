# Part 1 — Put the Code in Your Own GitHub Repo

**Goal:** Clone the starter project, prepare it for the pipeline, and push it to a new repository on your GitHub account.

**Pipeline:** **GitHub** → CodeBuild → CodeDeploy → EC2

---

## Step 1 — Clone the starter project

### 1.1 Clone

```bash
# Git Bash (Windows) or a terminal on Mac/Linux
cd ~/Desktop
git clone https://github.com/Nahashon-Kimani/Week2Day3CodeDeployDemo.git elearning-pipeline
cd elearning-pipeline
ls
```

You should see the website (`index.html`, `css/`, `img/`, `js/`, `lib/`), the deployment files (`buildspec.yml`, `appspec.yml`, `scripts/`) and two guide folders (`hosting/`, `codepipeline/`).

### 1.2 Delete the `.git` folder

The clone still contains the instructor's Git history, and its `origin` points to the instructor's repo, which you can't push to. Delete `.git` so you can start your own repo.

> `.git` is a hidden folder. Use `ls -a` to see it.

**Git Bash / Mac / Linux:**

```bash
pwd            # make sure you're inside elearning-pipeline
rm -rf .git
```

**PowerShell (Windows):**

```powershell
Remove-Item -Recurse -Force .git
```

Check that it's gone:

```bash
git status     # should print: fatal: not a git repository
```

> ⚠️ Run the delete command **only inside `elearning-pipeline`**. Running it in another folder wipes that project's Git history.

---

## Step 2 — Look at the deployment files

These files are already in the project. You don't need to create them, but you do need to understand them.

```
elearning-pipeline/
├── index.html, about.html, ...   <- the website
├── css/  img/  js/  lib/
├── buildspec.yml                 <- instructions for CodeBuild   (Build stage)
├── appspec.yml                   <- instructions for CodeDeploy  (Deploy stage)
├── scripts/                      <- scripts CodeDeploy runs on the server
│   ├── install_dependencies.sh   <- installs Apache
│   ├── start_server.sh           <- starts Apache
│   └── validate_service.sh       <- checks the home page loads
├── hosting/                      <- guides for the manual lab (not deployed)
└── codepipeline/                 <- these guides (not deployed)
```

| File | Which stage uses it | What it does |
|---|---|---|
| `buildspec.yml` | Build (CodeBuild) | Checks the project structure, fixes line endings, makes the scripts executable, writes `build-info.txt`, and lists which files go into the build artifact |
| `appspec.yml` | Deploy (CodeDeploy) | Copies the files to `/var/www/html` and runs the three scripts at the right moments |
| `scripts/*.sh` | Deploy (CodeDeploy agent on EC2) | Install, start and test Apache |

---

## Step 3 — Update `buildspec.yml` for the pipeline

Open `buildspec.yml` in VS Code and make one change.

**Record the Git commit.** When CodeBuild runs inside a pipeline, it receives a zip of your code rather than the Git repo itself, so it can't always tell which commit it's building. In Part 3 the pipeline will pass the commit ID to CodeBuild as a variable called `COMMIT_ID`.

Find this line:

```yaml
      - echo "Commit    $CODEBUILD_RESOLVED_SOURCE_VERSION"  >> build-info.txt
```

and replace it with:

```yaml
      - echo "Commit    $COMMIT_ID"                         >> build-info.txt
```

Save the file.

> YAML is indentation-sensitive. Keep the line indented exactly as it was, using spaces, never tabs.

While the file is open, look at the `artifacts` section at the bottom. `exclude-paths` keeps the Git data, both guide folders and the build config off the web server:

```yaml
artifacts:
  files:
    - '**/*'
  exclude-paths:
    - '.git/**/*'
    - 'hosting/**/*'
    - 'codepipeline/**/*'
    - 'buildspec.yml'
    - '.gitattributes'
```

---

## Step 4 — Create the repository on GitHub

1. Go to <https://github.com> → **+** (top right) → **New repository**.
2. **Repository name:** `elearning-pipeline`
3. **Visibility:** Public or Private. Both work.
4. **Leave unticked:** *Add a README*, *.gitignore* and *license*. The repo must start empty.
5. Click **Create repository** and copy the HTTPS URL, for example `https://github.com/<your-username>/elearning-pipeline.git`.

---

## Step 5 — Commit and push

```bash
# One-time setup (skip if you've already done this)
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

# Start a new repository on the 'main' branch
git init -b main

# Stage everything
git add .

# Mark the scripts as executable. Windows can't set this on its own,
# and without it CodeDeploy fails with "Permission denied".
git update-index --chmod=+x scripts/install_dependencies.sh scripts/start_server.sh scripts/validate_service.sh

# Commit
git commit -m "Initial commit: eLearning site for CodePipeline"

# Connect to your GitHub repo and push
git remote add origin https://github.com/<your-username>/elearning-pipeline.git
git push -u origin main
```

**Authentication:**
- **Windows:** a browser window opens. Sign in to GitHub and authorise.
- **Mac/Linux:** when asked for a password, paste a **Personal Access Token**, not your password. Create one at GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**, with **Contents: Read and write** on this repo.

---

## Step 6 — Verify

1. Refresh your repo page on GitHub.
2. You should see `buildspec.yml`, `appspec.yml` and `scripts/` in the root.
3. Open `buildspec.yml` on GitHub and check that it contains `$COMMIT_ID` and `codepipeline/**/*`.

✅ **Done.** Next: [2-ec2-codedeploy.md](2-ec2-codedeploy.md)

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `git init` says *Reinitialized existing Git repository* | `.git` wasn't deleted. Go back to Step 1.2. |
| Push is denied with 403, or goes to `Nahashon-Kimani/...` | Same cause. Delete `.git`, then redo Step 5. |
| `rejected ... fetch first` | You created the repo with a README. Run `git pull origin main --rebase`, then push again. |
| `Authentication failed` | Use a Personal Access Token, or clear old GitHub entries in Windows **Credential Manager**. |
| `src refspec main does not match any` | You haven't committed yet. Run `git commit` first. |

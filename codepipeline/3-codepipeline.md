# Part 3 — Create the Pipeline

**Goal:** Create a CodePipeline with three stages: **Source** (GitHub), **Build** (CodeBuild) and **Deploy** (CodeDeploy). Then watch it release your site to EC2 without a single manual build or deployment.

**Pipeline:** **GitHub** → **CodeBuild** → **CodeDeploy** → **EC2**

> Region: **us-east-1**. Replace `<yourname>` with your suffix everywhere.

---

## Key concepts

| Term | Meaning |
|---|---|
| **Pipeline** | An automated workflow made of stages. A new run (an **execution**) starts on every push to `main`. |
| **Stage** | One step of the pipeline: Source, Build or Deploy. A stage must succeed before the next one starts. |
| **Action** | The work done inside a stage, for example "run CodeBuild project X" |
| **Artifact** | The zip of files passed from one stage to the next, stored in the pipeline's S3 bucket |
| **Connection** | Gives AWS permission to read your GitHub repo and be notified when you push |
| **Variable** | A value one stage passes to another, for example the commit ID from Source |

How the artifacts flow:

```
Source ──SourceArtifact──▶ Build ──BuildArtifact──▶ Deploy
(zip of your repo)         (zip after buildspec.yml)  (CodeDeploy unpacks it on EC2)
```

---

## Step 1 — Start the pipeline wizard

1. Open **CodePipeline** → **Pipelines** → **Create pipeline**.
2. **Creation options:** **Build custom pipeline** → **Next**.

> The wizard opens pop-up windows in Steps 3 and 4. If your browser blocks them, allow pop-ups for `console.aws.amazon.com`.

---

## Step 2 — Pipeline settings

| Setting | Value |
|---|---|
| **Pipeline name** | `elearning-pipeline-<yourname>` |
| **Execution mode** | Leave the default |
| **Service role** | **New service role**. Accept the suggested name (it includes your pipeline name), and keep **Allow AWS CodePipeline to create a service role** ticked. |
| **Advanced settings** | Leave the defaults: **Default location** for the artifact store, **Default AWS Managed Key** for encryption |

Click **Next**.

> The **default location** is a bucket called `codepipeline-us-east-1-<numbers>`. It's created the first time anyone in the account creates a pipeline, and it's shared by every pipeline in the region.

---

## Step 3 — Source stage (GitHub)

| Setting | Value |
|---|---|
| **Source provider** | **GitHub (via GitHub App)** |
| **Connection** | Pick yours if it's listed. If not, click **Connect to GitHub** (see below). |
| **Repository name** | `<your-username>/elearning-pipeline` |
| **Default branch** | `main` |
| **Output artifact format** | **CodePipeline default** |
| **Trigger** | Keep the webhook trigger on, with **No filter**. Every push to `main` starts the pipeline. |

**Creating the connection** (if you don't have one):

1. Click **Connect to GitHub**. A pop-up opens.
2. **Connection name:** `github-<yourname>` → **Connect to GitHub**.
3. **GitHub Apps:** click **Install a new app** → sign in to GitHub → choose **Only select repositories** → select `elearning-pipeline` → **Install**.
4. Back in the pop-up, click **Connect**. The pop-up closes and the connection shows **Ready to connect**.

Click **Next**.

---

## Step 4 — Build stage (CodeBuild)

| Setting | Value |
|---|---|
| **Build provider** | **Other build providers** → **AWS CodeBuild** |
| **Region** | US East (N. Virginia) |
| **Input artifacts** | `SourceArtifact` |
| **Project name** | Click **Create project**. A pop-up opens; fill it in using the table below. |

### 4.1 Create the build project (in the pop-up)

| Setting | Value |
|---|---|
| **Project name** | `elearning-build-<yourname>` |
| **Provisioning model** | On-demand |
| **Environment image** | Managed image |
| **Compute** | EC2 |
| **Operating system** | Amazon Linux |
| **Runtime(s)** | Standard |
| **Image** | The latest `aws/codebuild/amazonlinux-x86_64-standard:...` |
| **Service role** | **New service role**. Accept the suggested name. |
| **Buildspec** | **Use a buildspec file**; leave **Buildspec name** blank |
| **Logs** | ✅ **CloudWatch logs**. Leave group and stream names blank to use the defaults. |

Click **Continue to CodePipeline**. The pop-up closes and the project name is filled in.

> Notice that the pop-up didn't ask about the **source** or the **artifacts**. Inside a pipeline, CodeBuild gets its source from the Source stage and passes its output to the Deploy stage, so you don't configure an S3 location.

### 4.2 Pass the commit ID to the build

Still in the Build stage, under **Environment variables**, click **Add environment variable**:

| Name | Value | Type |
|---|---|---|
| `COMMIT_ID` | `#{SourceVariables.CommitId}` | Plaintext |

`#{SourceVariables.CommitId}` is replaced by the Git commit the Source stage fetched. `buildspec.yml` writes it to `build-info.txt` (you set that up in Part 1, Step 3), so you can always check which commit is live.

- **Build type:** Single build

Click **Next**.

---

## Step 5 — Test stage

Click **Skip test stage** → **Skip**.

---

## Step 6 — Deploy stage (CodeDeploy)

| Setting | Value |
|---|---|
| **Deploy provider** | **AWS CodeDeploy** |
| **Region** | US East (N. Virginia) |
| **Input artifacts** | `BuildArtifact` |
| **Application name** | `elearning-app-<yourname>` |
| **Deployment group** | `elearning-dg-<yourname>` |

Click **Next**.

> **Input artifact** must be `BuildArtifact`, not `SourceArtifact`. `BuildArtifact` is the output of `buildspec.yml`: scripts made executable, `build-info.txt` added, guide folders removed.

---

## Step 7 — Review and create

Check every stage on the review page, then click **Create pipeline**.

The pipeline starts its first execution straight away.

---

## Step 8 — Watch the first release

On the pipeline page, each stage turns blue (**In progress**), then green (**Succeeded**):

```
Source ✔  →  Build ✔  →  Deploy ✔
~10 sec      ~1–2 min     ~1–2 min
```

While it runs, click **View details** on a stage to see what's happening:

- **Build → View details → View in CodeBuild:** the live build log. Look for `Validating project structure...` and `Build completed`.
- **Deploy → View details:** opens the CodeDeploy deployment. Under **Deployment lifecycle events**, click **View events** to watch `BeforeInstall → Install → ApplicationStart → ValidateService`.
- **EC2 terminal** (if you kept the agent log tail running from Part 2): you can watch the agent download and install the revision.

---

## Step 9 — Test the website

1. Open `http://<public-ip>` in your browser. Use **http**, not https.
2. The eLearning site should load. 🎉
3. Open `http://<public-ip>/build-info.txt`. The **Commit** line should match your latest commit:

```bash
# on your computer, in elearning-pipeline/
git log -1 --format=%H
```

On the instance, you can also check:

```bash
ls -l /var/www/html
cat /var/www/html/build-info.txt
```

✅ **Done.** Your pipeline is live. Next: [4-update-site.md](4-update-site.md)

---

## Troubleshooting

To find the cause of any failure, click **View details** on the failed stage. For Deploy, click **View events** on your instance and read the **first** event marked **Failed**.

| Stage | Symptom | Fix |
|---|---|---|
| Source | *Unable to use Connection* / connection **Pending** | Developer Tools → **Settings** → **Connections** → select your connection → **Update pending connection** → finish the GitHub App install. Then **Release change**. |
| Source | *Could not access the repository* | The GitHub App wasn't given access to the repo. On GitHub: **Settings** → **Applications** → *AWS Connector for GitHub* → **Configure** → add `elearning-pipeline`. |
| Build | `YAML_FILE_ERROR` | Indentation error in `buildspec.yml` (usually from Part 1, Step 3). Use spaces, not tabs. Fix, commit and push. |
| Build | `COMMAND_EXECUTION_ERROR ... test -f appspec.yml` | `appspec.yml` is missing from the repo root. |
| Build | `AccessDenied` on the `codepipeline-us-east-1-...` bucket | The CodeBuild service role can't use the artifact bucket. Add `s3:GetObject` and `s3:PutObject` on `arn:aws:s3:::codepipeline-us-east-1-*/*` to the role, then **Release change**. |
| Build | `build-info.txt` shows an empty commit | The `COMMIT_ID` variable is missing. Edit the pipeline → Build stage → edit the action → add it (Step 4.2). |
| Deploy | *No instances found* / deployment group has 0 instances | The Name tag doesn't match. See Part 2, Step 6. |
| Deploy | Stuck **In progress**, then *agent not responding* | The agent isn't running, or the instance has no IAM role. Check `sudo systemctl status codedeploy-agent`, attach `EC2-CodeDeploy-Role-<yourname>`, then restart the agent. |
| Deploy | **DownloadBundle**: `Access Denied` | The instance role is missing `AmazonS3ReadOnlyAccess`. Attach it and restart the agent. |
| Deploy | **BeforeInstall**: `/bin/bash^M: bad interpreter` | Windows line endings in the scripts. In VS Code, switch each `.sh` file from `CRLF` to `LF` (bottom-right status bar), then commit and push. |
| Deploy | **BeforeInstall**: `Permission denied` | Scripts aren't executable. Run `git update-index --chmod=+x scripts/*.sh`, then commit and push. |
| Deploy | **ValidateService** fails | Apache isn't serving the page. On the instance, run `sudo systemctl status httpd` and `curl -I localhost`. |
| — | Site doesn't load in the browser | The security group needs inbound **HTTP 80** from *Anywhere*, and the URL must start with `http://`. |

**Re-running the pipeline:** after fixing something in AWS (not in code), click **Release change** at the top of the pipeline page to run it again with the latest commit. If you fixed it in code, just push.

Detailed script output on the instance:

```bash
sudo tail -n 100 /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log
```

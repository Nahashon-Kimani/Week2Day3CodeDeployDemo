# Part 2 — AWS CodeBuild: Build and Store Artifacts in S3

**Goal:** Create a CodeBuild project that pulls code from GitHub, runs `buildspec.yml`, saves a **zip artifact to S3** and sends build logs to **CloudWatch Logs**.

**Lab flow:** GitHub → **CodeBuild** → **S3 (artifact)** → CodeDeploy → EC2

> **Region:** use **one region** for everything in this lab: the S3 bucket, CodeBuild, CodeDeploy and EC2. The examples use `us-east-1`.

---

## Key concepts

| Term | Meaning |
|---|---|
| **Build project** | Configuration that says where the source is, what machine to build on, and where outputs go |
| **buildspec.yml** | YAML file in the repo root with the commands CodeBuild runs |
| **Phases** | `install` → `pre_build` → `build` → `post_build`. If a command fails, the build fails. |
| **Artifact** | The build output (here, a zip of the website plus `appspec.yml` and `scripts/`) |
| **Service role** | IAM role CodeBuild assumes to write to S3 and CloudWatch |

### What our `buildspec.yml` does

- **pre_build:** checks that `index.html`, `appspec.yml` and `scripts/` exist, and fails fast if they don't.
- **build:** removes Windows line endings, runs `chmod +x` on the scripts, and writes `build-info.txt` with the build ID and commit.
- **artifacts:** packages everything except `.git`, `hosting/` (these guides) and the build config itself.

---

## Step 1 — Create the S3 artifact bucket

1. Open **S3** → **Create bucket**.
2. **Bucket type:** General purpose
3. **Bucket name:** `elearning-artifacts-<yourname>-<random digits>`. Bucket names must be globally unique and lowercase.
4. **Region:** the lab region, for example `us-east-1`
5. **Block all public access:** leave it **ON**. Artifacts should never be public.
6. **Bucket Versioning:** Enable (optional). Each build then keeps its previous versions, which is useful for rollbacks.
7. Click **Create bucket**.

CLI alternative:

```bash
aws s3 mb s3://elearning-artifacts-<yourname>-<digits> --region us-east-1
```

📝 Note your bucket name: `______________________________`

---

## Step 2 — Create the CodeBuild project

Open **CodeBuild** → **Build projects** → **Create build project**.

### 2.1 Project configuration
- **Project name:** `elearning-build`
- **Description:** `Builds the eLearning static site`

### 2.2 Source
- **Source provider:** GitHub
- **Credential:** if it shows *not connected*, click **Manage account credentials**:
  - Choose **GitHub App** (recommended) → **Create a new GitHub connection** → name it `github-elearning` → **Connect to GitHub** → **Install a new app** → authorise it for your `elearning-cicd` repository → **Connect**.
  - Or choose **OAuth** → **Connect to GitHub** → authorise in the popup.
  - Save the credential.
- **Repository:** *Repository in my GitHub account* → choose `elearning-cicd`
- **Source version:** `main` (optional; the default branch is used if left blank)

### 2.3 Primary source webhook events (optional, but good for the CI demo)
- Tick **Rebuild every time a code change is pushed to this repository**
- **Build type:** Single build
- **Event type:** `PUSH`

### 2.4 Environment
- **Provisioning model:** On-demand
- **Environment image:** Managed image
- **Compute:** EC2
- **Operating system:** Amazon Linux
- **Runtime(s):** Standard
- **Image:** `aws/codebuild/amazonlinux-x86_64-standard:5.0` (or the latest listed)
- **Service role:** **New service role**. Accept the suggested name, for example `codebuild-elearning-build-service-role`.
- Under **Additional configuration**, keep compute at **3 GB memory, 2 vCPUs**. That's the smallest size and plenty for this build.

### 2.5 Buildspec
- **Build specifications:** **Use a buildspec file**
- **Buildspec name:** leave blank. CodeBuild looks for `buildspec.yml` in the repo root.

### 2.6 Artifacts — push to S3
- **Type:** Amazon S3
- **Bucket name:** your artifact bucket from Step 1
- **Name:** `elearning-artifact.zip`
- **Path:** leave blank
- **Namespace type:** None
- **Artifacts packaging:** **Zip**

The artifact will be stored at:

```
s3://<your-bucket>/elearning-artifact.zip
```

Each new build overwrites this file. With bucket versioning on, the older versions are kept.

### 2.7 Logs — CloudWatch
- ✅ **CloudWatch logs** (ticked)
- **Group name:** `/aws/codebuild/elearning-build`
- **Stream name prefix:** `build`
- *(Optional)* ✅ **S3 logs**, bucket = your artifact bucket, path prefix = `build-logs`. This keeps a second copy of the logs in S3.

Click **Create build project**.

---

## Step 3 — Run the build

1. On the `elearning-build` project page, click **Start build**.
2. Watch the **Phase details** tab. Each phase should show **Succeeded**:
   `SUBMITTED → QUEUED → PROVISIONING → DOWNLOAD_SOURCE → INSTALL → PRE_BUILD → BUILD → POST_BUILD → UPLOAD_ARTIFACTS → FINALIZING → COMPLETED`
3. The **Build logs** tab shows the output live. Look for `Build started on ...` and the `test -f` checks.

CLI alternative:

```bash
aws codebuild start-build --project-name elearning-build
aws codebuild list-builds-for-project --project-name elearning-build
```

---

## Step 4 — Verify the artifact in S3

1. Open **S3** → your bucket. You should see `elearning-artifact.zip`.
2. Optional: download it and open it. It should contain `index.html`, `css/`, `img/`, `appspec.yml`, `scripts/` and `build-info.txt`, but **not** `hosting/` or `.git/`.

```bash
aws s3 ls s3://<your-bucket>/
```

📝 Note the artifact location: `s3://______________________/elearning-artifact.zip`

---

## Step 5 — Verify logs in CloudWatch

1. Open **CloudWatch** → **Logs** → **Log groups**.
2. Open `/aws/codebuild/elearning-build`.
3. Open the newest log stream (`build/<build-id>`). It holds the same output you saw in the console.

Teaching points:
- Logs are kept **after the build container is destroyed**, so you can debug old builds.
- By default the group's **retention** is *Never expire*. Set it to 1 week via **Actions → Edit retention setting** to control cost.
- You can search across builds with **Logs Insights**, for example:

```
fields @timestamp, @message
| filter @message like /ERROR|error|failed/
| sort @timestamp desc
```

CLI alternative:

```bash
aws logs tail /aws/codebuild/elearning-build --since 1h
```

---

## Step 6 — Demonstrate CI (if you enabled the webhook)

```bash
# Change the page title in index.html, then:
git add index.html
git commit -m "Change homepage title"
git push
```

Back in CodeBuild → **Build history**, a new build starts automatically, triggered by the push.

✅ **Done.** Next: [codedeploy.md](codedeploy.md)

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `YAML_FILE_ERROR` | Indentation error in `buildspec.yml`. YAML needs spaces, not tabs. |
| `COMMAND_EXECUTION_ERROR ... test -f appspec.yml` | `appspec.yml` is missing from the repo root or misspelled (it's case-sensitive). |
| `CLIENT_ERROR: authentication required` at DOWNLOAD_SOURCE | GitHub connection expired or lacks access to the repo. Reconnect under **Manage account credentials**. |
| `AccessDenied` at UPLOAD_ARTIFACTS | Service role can't write to the bucket. Add `s3:PutObject` on `arn:aws:s3:::<bucket>/*` to the CodeBuild service role. |
| Bucket not listed in the Artifacts dropdown | Bucket is in a different region. Recreate it in the CodeBuild region. |

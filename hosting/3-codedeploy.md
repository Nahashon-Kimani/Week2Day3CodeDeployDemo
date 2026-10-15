# Part 3 — AWS CodeDeploy: Deploy to an EC2 t3.micro

**Goal:** Launch an EC2 instance, install the **CodeDeploy agent**, then deploy the S3 artifact built by CodeBuild so Apache serves the eLearning site.

**Lab flow:** GitHub → CodeBuild → S3 (artifact) → **CodeDeploy** → **EC2 (Apache)**

---

## Key concepts

| Term | Meaning |
|---|---|
| **Application** | Container for what you deploy (`elearning-app`) |
| **Deployment group** | *Where* to deploy: the set of instances, chosen here by **tag** |
| **Revision** | *What* to deploy: our `elearning-artifact.zip` in S3 |
| **appspec.yml** | Says where files go and which scripts run at each lifecycle event |
| **CodeDeploy agent** | Software on the EC2 instance that polls CodeDeploy, downloads the revision from S3 and runs the hooks |
| **Deployment configuration** | How many instances at a time (`AllAtOnce`, `HalfAtATime`, `OneAtATime`) |

### What the agent does during an in-place deployment

```
ApplicationStop → DownloadBundle → BeforeInstall → Install → AfterInstall
                → ApplicationStart → ValidateService
```

In our `appspec.yml`:

| Hook | Script | Purpose |
|---|---|---|
| `BeforeInstall` | `install_dependencies.sh` | Install Apache (`httpd`) |
| `Install` | *(built-in)* | Copy the bundle to `/var/www/html` (the `files:` section) |
| `ApplicationStart` | `start_server.sh` | Enable and restart Apache |
| `ValidateService` | `validate_service.sh` | `curl` the home page and fail the deployment if it isn't served |

---

## Step 1 — IAM role for the EC2 instance

The instance needs permission to **download the revision from S3**. SSM access is optional but lets you open a shell from the browser.

1. **IAM** → **Roles** → **Create role**
2. **Trusted entity:** AWS service → **Use case: EC2** → Next
3. Attach these policies:
   - `AmazonS3ReadOnlyAccess`
   - `AmazonSSMManagedInstanceCore` (optional, for Session Manager)
4. **Role name:** `EC2-CodeDeploy-Role` → **Create role**

> In production you would scope S3 access to just the artifact bucket. Read-only on all buckets keeps the classroom setup simple.

---

## Step 2 — IAM service role for CodeDeploy

CodeDeploy itself needs permission to read EC2 tags and manage deployments.

1. **IAM** → **Roles** → **Create role**
2. **Trusted entity:** AWS service → choose **CodeDeploy** → use case **CodeDeploy** → Next
3. The `AWSCodeDeployRole` policy is attached automatically → Next
4. **Role name:** `CodeDeployServiceRole` → **Create role**

---

## Step 3 — Launch the EC2 instance (t3.micro)

**EC2** → **Instances** → **Launch instances**

| Setting | Value |
|---|---|
| **Name** | `elearning-web`. This creates the tag `Name = elearning-web`, which the deployment group uses to find the instance. |
| **AMI** | Amazon Linux 2023 AMI (64-bit x86) |
| **Instance type** | `t3.micro` |
| **Key pair** | Create or choose one (or skip it and use EC2 Instance Connect or Session Manager) |
| **Network** | Default VPC, public subnet, **Auto-assign public IP: Enable** |
| **Security group** | Create new: `elearning-web-sg`<br>• **SSH (22)**, source *My IP*<br>• **HTTP (80)**, source *Anywhere 0.0.0.0/0* |
| **Advanced details → IAM instance profile** | `EC2-CodeDeploy-Role` |

### Install the CodeDeploy agent with User data

In **Advanced details → User data**, paste:

```bash
#!/bin/bash
dnf update -y
dnf install -y ruby wget

# Work out the region from instance metadata (IMDSv2)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

# Download and install the CodeDeploy agent for this region
cd /home/ec2-user
wget "https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
chmod +x ./install
./install auto

systemctl enable codedeploy-agent
systemctl start codedeploy-agent
```

Click **Launch instance**. Wait until **Instance state = Running** and **Status checks = 2/2 passed**, which takes about 2–3 minutes.

---

## Step 4 — Verify (or manually install) the CodeDeploy agent

Connect to the instance: select it → **Connect** → **EC2 Instance Connect** → **Connect**.

```bash
sudo systemctl status codedeploy-agent
```

You want to see `active (running)`.

### Manual install (if you skipped User data or it failed)

```bash
sudo dnf install -y ruby wget
cd /home/ec2-user
REGION=us-east-1           # <-- change to your region
wget https://aws-codedeploy-$REGION.s3.$REGION.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl start codedeploy-agent
sudo systemctl status codedeploy-agent
```

### Useful agent commands

```bash
sudo systemctl restart codedeploy-agent                         # restart (e.g. after attaching an IAM role)
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log  # agent log
cat /var/log/cloud-init-output.log                              # User data output, if the install failed
```

> ⚠️ If you attached the IAM role **after** the agent started, run `sudo systemctl restart codedeploy-agent` so it picks up the credentials.

---

## Step 5 — Create the CodeDeploy application

1. **CodeDeploy** → **Applications** → **Create application**
2. **Application name:** `elearning-app`
3. **Compute platform:** **EC2/On-premises**
4. **Create application**

---

## Step 6 — Create the deployment group

Inside `elearning-app` → **Deployment groups** → **Create deployment group**

| Setting | Value |
|---|---|
| **Deployment group name** | `elearning-dg` |
| **Service role** | `CodeDeployServiceRole` |
| **Deployment type** | **In-place** |
| **Environment configuration** | ✅ **Amazon EC2 instances**<br>Tag group: **Key** `Name`, **Value** `elearning-web`<br>The console should say *1 unique matched instance*. |
| **Agent configuration with AWS Systems Manager** | **Never**. We already installed the agent ourselves. |
| **Deployment settings** | `CodeDeployDefault.AllAtOnce` |
| **Load balancer** | ❌ Untick *Enable load balancing* |

Click **Create deployment group**.

---

## Step 7 — Deploy the S3 artifact

Inside `elearning-dg` → **Create deployment**

| Setting | Value |
|---|---|
| **Revision type** | *My application is stored in Amazon S3* |
| **Revision location** | `s3://<your-bucket>/elearning-artifact.zip` |
| **Revision file type** | `.zip` |
| **Additional deployment behavior settings** | *Overwrite the content* (matches `file_exists_behavior: OVERWRITE` in the appspec) |

Click **Create deployment**.

CLI alternative:

```bash
aws deploy create-deployment \
  --application-name elearning-app \
  --deployment-group-name elearning-dg \
  --s3-location bucket=<your-bucket>,key=elearning-artifact.zip,bundleType=zip \
  --file-exists-behavior OVERWRITE
```

### Watch it run

On the deployment page, scroll to **Deployment lifecycle events** → **View events**. Every event should end in **Succeeded**:

```
ApplicationStop ✔  DownloadBundle ✔  BeforeInstall ✔  Install ✔
AfterInstall ✔  ApplicationStart ✔  ValidateService ✔
```

---

## Step 8 — Test the website

1. Copy the instance's **Public IPv4 address** from the EC2 console.
2. Open `http://<public-ip>` in a browser. Use **http**, not https.
3. The eLearning site should load. 🎉
4. Open `http://<public-ip>/build-info.txt` to see which CodeBuild build and Git commit are live.

On the instance:

```bash
ls -l /var/www/html
cat /var/www/html/build-info.txt
```

---

## Step 9 — Full CI/CD loop (class demo)

1. Edit `index.html` locally, for example change the hero heading text.
2. `git add . && git commit -m "Update hero text" && git push`
3. **CodeBuild** builds automatically (webhook) and overwrites `elearning-artifact.zip` in S3.
4. **CodeDeploy** → `elearning-dg` → **Create deployment** with the same S3 location.
5. Refresh the browser and check `build-info.txt`. The new commit ID is live.

> To make step 4 automatic, wire GitHub → CodeBuild → CodeDeploy together in **AWS CodePipeline**.

### Rollback demo
**CodeDeploy** → **Deployments** → choose an earlier successful deployment → **Retry deployment** (or **Redeploy**). With S3 versioning on, you can also deploy an older object version.

---

## Troubleshooting

| Symptom | Where to look / fix |
|---|---|
| Deployment group shows **0 matched instances** | The tag key or value doesn't match. Tags are case-sensitive (`Name` = `elearning-web`). |
| Deployment stuck **In progress / Pending**, then fails with *agent not responding* | Agent isn't running, or the instance has no IAM role. Run `sudo systemctl status codedeploy-agent`, attach `EC2-CodeDeploy-Role`, then restart the agent. |
| **DownloadBundle** fails with `Access Denied` | Instance role is missing S3 read access, or the bucket or key name is wrong. |
| **BeforeInstall**: `/bin/bash^M: bad interpreter` | CRLF line endings. Check `.gitattributes`, convert the files to LF and push again. |
| **BeforeInstall**: `Permission denied` | Script isn't executable. Run `git update-index --chmod=+x scripts/*.sh`, then commit and push. |
| **Install**: `file already exists at location` | Add `file_exists_behavior: OVERWRITE` to the appspec, or choose *Overwrite* when deploying. |
| **ValidateService** fails | Apache isn't serving the page. Run `sudo systemctl status httpd` and `curl -I localhost`. |
| Site doesn't load in the browser | Security group needs inbound **HTTP 80**, and the URL must be `http://`, not `https://`. |

Detailed per-deployment script output on the instance:

```bash
sudo tail -n 100 /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log
```

✅ **Done.** When the class is over: [cleanup.md](cleanup.md)

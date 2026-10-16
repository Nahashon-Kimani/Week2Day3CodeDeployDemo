# Part 2 — EC2 Web Server and CodeDeploy Application

**Goal:** Prepare the target for the pipeline's **Deploy** stage: an EC2 web server running the CodeDeploy agent, and a CodeDeploy application and deployment group that point at it.

**Pipeline:** GitHub → CodeBuild → **CodeDeploy** → **EC2**

> Region: **us-east-1**. Replace `<yourname>` with your suffix everywhere (see [README.md](README.md)).

---

## Key concepts

| Term | Meaning |
|---|---|
| **CodeDeploy agent** | Software on the EC2 instance. It checks CodeDeploy for new deployments, downloads the artifact from S3 and runs the scripts in `appspec.yml`. |
| **Application** | A container for what you deploy (`elearning-app-<yourname>`) |
| **Deployment group** | *Where* to deploy. Here it's the instance with the tag `Name = elearning-web-<yourname>`. |
| **Instance role** | Gives the EC2 instance permission to download artifacts from S3 |
| **Service role** | Gives CodeDeploy permission to find your instances by their tags |

What the agent does during each deployment:

```
ApplicationStop → DownloadBundle → BeforeInstall → Install → AfterInstall → ApplicationStart → ValidateService
                                   (install Apache)  (copy files)          (start Apache)    (curl home page)
```

---

## Step 1 — IAM role for the EC2 instance

The instance needs to **download the pipeline's artifacts from S3**.

1. **IAM** → **Roles** → **Create role**
2. **Trusted entity:** AWS service → **Use case: EC2** → **Next**
3. Attach these policies:
   - `AmazonS3ReadOnlyAccess`
   - `AmazonSSMManagedInstanceCore` (optional; lets you open a shell with Session Manager)
4. **Next** → **Role name:** `EC2-CodeDeploy-Role-<yourname>` → **Create role**

> In production you would allow read access only to the pipeline's artifact bucket. Read-only access to all buckets keeps the classroom setup simple.

---

## Step 2 — IAM service role for CodeDeploy

1. **IAM** → **Roles** → **Create role**
2. **Trusted entity:** AWS service → choose **CodeDeploy** → use case **CodeDeploy** → **Next**
3. The `AWSCodeDeployRole` policy is attached automatically → **Next**
4. **Role name:** `CodeDeployServiceRole-<yourname>` → **Create role**

---

## Step 3 — Launch the EC2 instance

**EC2** → **Instances** → **Launch instances**

| Setting | Value |
|---|---|
| **Name** | `elearning-web-<yourname>`. This creates the tag `Name = elearning-web-<yourname>`, which CodeDeploy uses to find your server. |
| **AMI** | Amazon Linux 2023 AMI (64-bit x86) |
| **Instance type** | `t3.micro` |
| **Key pair** | **Proceed without a key pair**. You'll connect with EC2 Instance Connect in the browser. |
| **Network settings** → **Edit** | Default VPC, any public subnet, **Auto-assign public IP: Enable** |
| **Security group** | **Create security group**, name `elearning-web-sg-<yourname>`<br>• **SSH (22)**, source *Anywhere 0.0.0.0/0* (needed for EC2 Instance Connect in the browser)<br>• **HTTP (80)**, source *Anywhere 0.0.0.0/0* |
| **Advanced details → IAM instance profile** | `EC2-CodeDeploy-Role-<yourname>` |

Leave **User data** empty. You'll install the agent by hand in Step 4.

Click **Launch instance**. Wait until **Instance state = Running** and **Status checks = 2/2 passed**, which takes about 2–3 minutes.

📝 Public IPv4 address: `______________________`

---

## Step 4 — Install the CodeDeploy agent

Select your instance → **Connect** → **EC2 Instance Connect** → **Connect**. A terminal opens in your browser, logged in as `ec2-user`.

Run the commands **one at a time**, and check each one finishes without errors before running the next.

**4.1 Update the system packages.** This brings the OS up to date before you install anything. It can take a minute.

```bash
sudo dnf update -y
```

**4.2 Install Ruby and wget.** The agent is written in Ruby, so it needs Ruby to run. `wget` downloads the installer.

```bash
sudo dnf install -y ruby wget
```

**4.3 Get a metadata token.** Every EC2 instance can query information about itself at `169.254.169.254`. Amazon Linux 2023 requires a session token first (this is called IMDSv2).

```bash
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
```

**4.4 Find the region.** This uses the token to ask which region the instance runs in. It should print `us-east-1`.

```bash
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
echo $REGION
```

> If it prints nothing, set it yourself: `REGION=us-east-1`

**4.5 Go to your home folder.** The installer will be downloaded here.

```bash
cd /home/ec2-user
```

**4.6 Download the agent installer.** AWS hosts a copy in every region; `$REGION` picks yours.

```bash
wget "https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
```

**4.7 Make the installer executable.**

```bash
chmod +x ./install
```

**4.8 Run the installer.** `auto` picks the right agent version for this operating system.

```bash
sudo ./install auto
```

**4.9 Start the agent now, and on every boot.**

```bash
sudo systemctl enable codedeploy-agent
sudo systemctl start codedeploy-agent
```

**4.10 Check the agent is running.** Look for `active (running)`. Press `q` to exit.

```bash
sudo systemctl status codedeploy-agent
```

> ⚠️ `TOKEN` and `REGION` only last for the current terminal session. If you disconnect partway through, re-run 4.3 and 4.4 first.

Keep this terminal tab open. It's useful for watching deployments in Part 3:

```bash
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log    # Ctrl+C to stop
```

---

## Step 5 — Create the CodeDeploy application

1. **CodeDeploy** → **Applications** → **Create application**
2. **Application name:** `elearning-app-<yourname>`
3. **Compute platform:** **EC2/On-premises**
4. **Create application**

---

## Step 6 — Create the deployment group

Inside `elearning-app-<yourname>` → **Deployment groups** tab → **Create deployment group**

| Setting | Value |
|---|---|
| **Deployment group name** | `elearning-dg-<yourname>` |
| **Service role** | `CodeDeployServiceRole-<yourname>` |
| **Deployment type** | **In-place** |
| **Environment configuration** | ✅ **Amazon EC2 instances**<br>Tag group 1: **Key** `Name`, **Value** `elearning-web-<yourname>`<br>Below the tags, the console must say **1 unique matched instance**. |
| **Agent configuration with AWS Systems Manager** | **Never**. You've already installed the agent. |
| **Deployment settings** | `CodeDeployDefault.AllAtOnce` |
| **Load balancer** | Untick **Enable load balancing** |

Click **Create deployment group**.

> Don't create a deployment here. In this lab, the pipeline creates every deployment for you.

---

## Checklist before Part 3

- [ ] EC2 instance `elearning-web-<yourname>` is **Running**, with 2/2 status checks
- [ ] `sudo systemctl status codedeploy-agent` shows **active (running)**
- [ ] Application `elearning-app-<yourname>` exists
- [ ] Deployment group `elearning-dg-<yourname>` matches **exactly 1** instance

✅ **Done.** Next: [3-codepipeline.md](3-codepipeline.md)

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Deployment group shows **0 matched instances** | The tag doesn't match. Tags are case-sensitive: key `Name`, value exactly as you typed it on the instance. |
| Deployment group shows **more than 1** matched instance | Another instance has the same Name tag. Make sure yours is `elearning-web-<yourname>`. |
| EC2 Instance Connect fails to connect | The security group needs **SSH (22)** from *Anywhere*, and the instance needs a public IP. |
| `wget` gives *404 Not Found* | `REGION` is empty or wrong. Run `echo $REGION`, then repeat 4.3 and 4.4. |
| Agent status shows `failed` or `inactive` | Run `sudo systemctl restart codedeploy-agent`, then check the log: `sudo tail -n 50 /var/log/aws/codedeploy-agent/codedeploy-agent.log` |
| You attached the IAM role **after** starting the agent | Run `sudo systemctl restart codedeploy-agent` so it picks up the new permissions. |

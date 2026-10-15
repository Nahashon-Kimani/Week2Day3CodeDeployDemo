# Part 4 — Clean Up the Lab Environment

**Goal:** Delete everything created in this lab so nothing keeps charging. Work through the steps **in order**, because some resources depend on others.

| # | Resource | Created in |
|---|---|---|
| 1 | EC2 instance `elearning-web` | codedeploy.md |
| 2 | Security group `elearning-web-sg` (+ key pair) | codedeploy.md |
| 3 | CodeDeploy app `elearning-app` (+ deployment group) | codedeploy.md |
| 4 | CodeBuild project `elearning-build` | codebuild.md |
| 5 | CloudWatch log group `/aws/codebuild/elearning-build` | codebuild.md |
| 6 | S3 bucket `elearning-artifacts-...` | codebuild.md |
| 7 | IAM roles and policies | codebuild.md / codedeploy.md |
| 8 | GitHub connection (CodeConnections) | codebuild.md |
| 9 | GitHub repo and token (optional) | github.md |

> 💰 The **EC2 instance** is the main cost. Delete it first, even if you skip everything else.

---

## Step 1 — Terminate the EC2 instance

**Console:** EC2 → Instances → select `elearning-web` → **Instance state** → **Terminate (delete) instance** → confirm.

Wait until the state is **Terminated** before deleting the security group.

**CLI:**

```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=elearning-web" "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
```

---

## Step 2 — Delete the security group and key pair

**Console:**
- EC2 → **Security Groups** → select `elearning-web-sg` → **Actions** → **Delete security groups**
- EC2 → **Key Pairs** → select the lab key → **Actions** → **Delete**. Also delete the `.pem` file from your computer.

**CLI:**

```bash
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=elearning-web-sg" \
  --query "SecurityGroups[0].GroupId" --output text)
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name <your-key-name>
```

---

## Step 3 — Delete the CodeDeploy application

Deleting the application also deletes its deployment groups.

**Console:** CodeDeploy → Applications → `elearning-app` → **Delete application** → type `delete` → **Delete**.

**CLI:**

```bash
aws deploy delete-application --application-name elearning-app
```

---

## Step 4 — Delete the CodeBuild project

**Console:** CodeBuild → Build projects → select `elearning-build` → **Actions** → **Delete** → type `delete`.

This also removes the GitHub webhook.

**CLI:**

```bash
aws codebuild delete-project --name elearning-build
```

---

## Step 5 — Delete the CloudWatch log group

Deleting the CodeBuild project does **not** delete its logs.

**Console:** CloudWatch → Logs → Log groups → select `/aws/codebuild/elearning-build` → **Actions** → **Delete log group(s)**.

**CLI:**

```bash
aws logs delete-log-group --log-group-name /aws/codebuild/elearning-build
```

---

## Step 6 — Empty and delete the S3 bucket

A bucket has to be empty before you can delete it. With **versioning** on, that includes all old versions.

**Console:**
1. S3 → select your `elearning-artifacts-...` bucket → **Empty** → type `permanently delete` → **Empty**.
2. Select the bucket again → **Delete** → type the bucket name → **Delete bucket**.

**CLI:**

```bash
BUCKET=elearning-artifacts-<yourname>-<digits>

# Without versioning:
aws s3 rb s3://$BUCKET --force

# With versioning on, remove all versions and delete markers first:
aws s3api delete-objects --bucket $BUCKET \
  --delete "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}}' --output json)"
aws s3 rb s3://$BUCKET
```

---

## Step 7 — Delete the IAM roles and policies

**Console:** IAM → **Roles** → search for each role → select it → **Delete** → type the role name:

| Role | Notes |
|---|---|
| `EC2-CodeDeploy-Role` | Also removes its instance profile when deleted from the console |
| `CodeDeployServiceRole` | |
| `codebuild-elearning-build-service-role` | Auto-created by CodeBuild |

Then IAM → **Policies** → filter **Customer managed** → delete `CodeBuildBasePolicy-elearning-build-<region>` and any other `CodeBuild...elearning-build...` policies that were auto-created.

**CLI (EC2 role example):**

```bash
aws iam remove-role-from-instance-profile --instance-profile-name EC2-CodeDeploy-Role --role-name EC2-CodeDeploy-Role
aws iam delete-instance-profile --instance-profile-name EC2-CodeDeploy-Role
aws iam detach-role-policy --role-name EC2-CodeDeploy-Role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam detach-role-policy --role-name EC2-CodeDeploy-Role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role --role-name EC2-CodeDeploy-Role

aws iam detach-role-policy --role-name CodeDeployServiceRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole
aws iam delete-role --role-name CodeDeployServiceRole
```

---

## Step 8 — Remove the GitHub connection

**Console:** Developer Tools → **Settings** → **Connections** → select `github-elearning` → **Delete**.

On GitHub: **Settings** → **Applications** → **Installed GitHub Apps** (or **Authorized OAuth Apps**) → find *AWS Connector for GitHub* → **Configure** → **Uninstall** (or **Revoke**).

---

## Step 9 — GitHub repo and token (optional)

Keep the repo if you want it in your portfolio. To delete it:
- Repo → **Settings** → scroll to **Danger Zone** → **Delete this repository**.

If you created a Personal Access Token for this lab:
- GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Delete**.

---

## Final check

- [ ] EC2 → Instances: `elearning-web` is **Terminated**
- [ ] EC2 → Elastic IPs: none left unassociated (if you created one)
- [ ] CodeDeploy → Applications: empty
- [ ] CodeBuild → Build projects: `elearning-build` is gone
- [ ] CloudWatch → Log groups: no `/aws/codebuild/elearning-build`
- [ ] S3: artifact bucket is gone
- [ ] IAM → Roles: the three lab roles are gone
- [ ] **Billing → Bills**: check again over the next day or two that no lab charges are still accruing

✅ Environment cleaned up.

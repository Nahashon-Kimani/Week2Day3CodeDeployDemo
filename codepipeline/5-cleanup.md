# Part 5 — Clean Up

**Goal:** Delete everything you created so nothing keeps running or charging. Work through the steps **in order**, because some resources depend on others.

> Replace `<yourname>` with your suffix. Delete **only your own** resources. Everyone shares this AWS account.

| # | Resource | Created in |
|---|---|---|
| 1 | Pipeline `elearning-pipeline-<yourname>` | 3-codepipeline.md |
| 2 | EC2 instance `elearning-web-<yourname>` | 2-ec2-codedeploy.md |
| 3 | Security group `elearning-web-sg-<yourname>` | 2-ec2-codedeploy.md |
| 4 | CodeDeploy app `elearning-app-<yourname>` (+ deployment group) | 2-ec2-codedeploy.md |
| 5 | CodeBuild project `elearning-build-<yourname>` + its log group | 3-codepipeline.md |
| 6 | IAM roles and policies (4 roles) | 2-ec2-codedeploy.md / 3-codepipeline.md |
| 7 | GitHub connection `github-<yourname>` | 3-codepipeline.md |
| 8 | GitHub repo (optional) | 1-github.md |

> 💰 The **EC2 instance** is the main cost. If you're short of time, delete it and the pipeline first.

---

## Step 1 — Delete the pipeline

Deleting the pipeline first stops a stray push from starting a new deployment while you clean up.

**Console:** CodePipeline → Pipelines → select `elearning-pipeline-<yourname>` → **Delete pipeline** → type `delete` → **Delete**.

**CLI:**

```bash
aws codepipeline delete-pipeline --name elearning-pipeline-<yourname>
```

> Leave the shared `codepipeline-us-east-1-...` artifact bucket alone. Other students' pipelines use it. Your instructor deletes it after the class (see the end of this guide).

---

## Step 2 — Terminate the EC2 instance

**Console:** EC2 → Instances → select `elearning-web-<yourname>` → **Instance state** → **Terminate (delete) instance** → confirm.

Wait until the state is **Terminated** before deleting the security group.

**CLI:**

```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=elearning-web-<yourname>" "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
```

---

## Step 3 — Delete the security group

**Console:** EC2 → **Security Groups** → select `elearning-web-sg-<yourname>` → **Actions** → **Delete security groups**.

**CLI:**

```bash
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=elearning-web-sg-<yourname>" \
  --query "SecurityGroups[0].GroupId" --output text)
aws ec2 delete-security-group --group-id $SG_ID
```

---

## Step 4 — Delete the CodeDeploy application

Deleting the application also deletes its deployment group.

**Console:** CodeDeploy → Applications → `elearning-app-<yourname>` → **Delete application** → type `delete` → **Delete**.

**CLI:**

```bash
aws deploy delete-application --application-name elearning-app-<yourname>
```

---

## Step 5 — Delete the CodeBuild project and its logs

**Console:**
1. CodeBuild → Build projects → select `elearning-build-<yourname>` → **Actions** → **Delete** → type `delete`.
2. CloudWatch → Logs → Log groups → select `/aws/codebuild/elearning-build-<yourname>` → **Actions** → **Delete log group(s)**. Deleting the project doesn't delete its logs.

**CLI:**

```bash
aws codebuild delete-project --name elearning-build-<yourname>
aws logs delete-log-group --log-group-name /aws/codebuild/elearning-build-<yourname>
```

---

## Step 6 — Delete the IAM roles and policies

**Console:** IAM → **Roles** → search for each role → select it → **Delete** → type the role name.

| Role | Created by |
|---|---|
| `EC2-CodeDeploy-Role-<yourname>` | You (Part 2). Deleting it in the console also removes its instance profile. |
| `CodeDeployServiceRole-<yourname>` | You (Part 2) |
| `codebuild-elearning-build-<yourname>-service-role` | CodeBuild (Part 3) |
| `AWSCodePipelineServiceRole-us-east-1-elearning-pipeline-<yourname>` | CodePipeline (Part 3) |

Then IAM → **Policies** → filter **Customer managed** → search for your suffix `<yourname>` and delete the policies that were created for you:
- `CodeBuildBasePolicy-elearning-build-<yourname>-us-east-1`
- `AWSCodePipelineServiceRole-us-east-1-elearning-pipeline-<yourname>`

> Search by your own suffix and delete only policies with your name in them.

**CLI (the two roles you created):**

```bash
aws iam remove-role-from-instance-profile --instance-profile-name EC2-CodeDeploy-Role-<yourname> --role-name EC2-CodeDeploy-Role-<yourname>
aws iam delete-instance-profile --instance-profile-name EC2-CodeDeploy-Role-<yourname>
aws iam detach-role-policy --role-name EC2-CodeDeploy-Role-<yourname> --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam detach-role-policy --role-name EC2-CodeDeploy-Role-<yourname> --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role --role-name EC2-CodeDeploy-Role-<yourname>

aws iam detach-role-policy --role-name CodeDeployServiceRole-<yourname> --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole
aws iam delete-role --role-name CodeDeployServiceRole-<yourname>
```

For the two auto-created roles, the console is easier: it detaches their policies for you.

---

## Step 7 — Remove the GitHub connection

**Console:** Developer Tools → **Settings** → **Connections** → select `github-<yourname>` → **Delete**.

On GitHub: **Settings** → **Applications** → **Installed GitHub Apps** → *AWS Connector for GitHub* → **Configure** → **Uninstall**.

---

## Step 8 — GitHub repo (optional)

Keep `elearning-pipeline` if you want it in your portfolio. To delete it: repo → **Settings** → **Danger Zone** → **Delete this repository**.

If you created a Personal Access Token for this lab: GitHub → **Settings** → **Developer settings** → **Personal access tokens** → delete it.

---

## Final check

- [ ] CodePipeline: `elearning-pipeline-<yourname>` is gone
- [ ] EC2 → Instances: `elearning-web-<yourname>` is **Terminated**
- [ ] EC2 → Security Groups: `elearning-web-sg-<yourname>` is gone
- [ ] CodeDeploy → Applications: `elearning-app-<yourname>` is gone
- [ ] CodeBuild: `elearning-build-<yourname>` is gone, along with its log group
- [ ] IAM → Roles: search `<yourname>` returns nothing
- [ ] Developer Tools → Connections: `github-<yourname>` is gone

✅ Environment cleaned up.

---

## Instructor only — delete the shared artifact bucket

After **every** student has finished, empty and delete the shared pipeline artifact bucket. It holds the artifacts of every pipeline in the region.

```bash
aws s3 ls | grep codepipeline-us-east-1     # find the bucket name
BUCKET=codepipeline-us-east-1-<numbers>
aws s3 rb s3://$BUCKET --force              # empties and deletes it
```

If any pipelines are still in use in the account, leave the bucket. Deleting it breaks them.

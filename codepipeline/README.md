# CI/CD with AWS CodePipeline — eLearning Site

**Goal:** Build a fully automated pipeline. When you `git push` to GitHub, the eLearning website is built by **CodeBuild** and deployed to an **EC2** web server by **CodeDeploy**. **CodePipeline** connects the stages, so after setup you never start a build or deployment by hand.

```
  git push
     │
     ▼
┌──────────┐    ┌──────────────┐    ┌───────────────┐    ┌──────────────┐
│  Source  │ ─▶ │    Build     │ ─▶ │    Deploy     │ ─▶ │  EC2 (Apache) │
│  GitHub  │    │  CodeBuild   │    │  CodeDeploy   │    │  live website │
└──────────┘    └──────────────┘    └───────────────┘    └──────────────┘
        └──────────── AWS CodePipeline runs all of this ────────────┘
```

Between stages, CodePipeline passes the files as zip **artifacts** through its own S3 bucket. You don't need to create a bucket.

---

## Lab parts

| Part | Guide | What you do | Time |
|---|---|---|---|
| 1 | [1-github.md](1-github.md) | Clone the starter code and push it to your own GitHub repo | 15 min |
| 2 | [2-ec2-codedeploy.md](2-ec2-codedeploy.md) | IAM roles, the EC2 web server, the CodeDeploy agent, the CodeDeploy application | 30 min |
| 3 | [3-codepipeline.md](3-codepipeline.md) | Create the pipeline (Source → Build → Deploy) and watch the first release | 25 min |
| 4 | [4-update-site.md](4-update-site.md) | Change the colour scheme and ship it with nothing but `git push` | 10 min |
| 5 | [5-cleanup.md](5-cleanup.md) | Delete everything | 10 min |

Do the parts **in order**. The pipeline's Deploy stage needs the EC2 instance and CodeDeploy application from Part 2 to exist already.

---

## Prerequisites

- An AWS account with console access
- A GitHub account
- Git installed (`git --version`). On Windows, use **Git Bash** for the commands.
- VS Code or another editor

---

## Rules for this lab

**1. One region.** Do everything in **US East (N. Virginia) `us-east-1`**. Check the region selector at the top right of the AWS console before each part.

**2. Unique names.** Everyone in the class shares the same AWS account, so names must not clash. Add `-<yourname>` to every resource you create, for example `elearning-app-jdoe`. Use lowercase letters only and keep it short.

📝 Your suffix: `-______________`

| Resource | Name |
|---|---|
| GitHub repo | `elearning-pipeline` (on your own GitHub, so no suffix needed) |
| GitHub connection | `github-<yourname>` |
| EC2 instance role | `EC2-CodeDeploy-Role-<yourname>` |
| CodeDeploy service role | `CodeDeployServiceRole-<yourname>` |
| EC2 instance (Name tag) | `elearning-web-<yourname>` |
| Security group | `elearning-web-sg-<yourname>` |
| CodeDeploy application | `elearning-app-<yourname>` |
| Deployment group | `elearning-dg-<yourname>` |
| CodeBuild project | `elearning-build-<yourname>` |
| Pipeline | `elearning-pipeline-<yourname>` |

> ⚠️ The EC2 **Name tag** matters most. CodeDeploy finds your server by that tag. If two students use the same name, each deployment goes to both servers.

---

## Cost

| Service | Cost for this lab |
|---|---|
| EC2 `t3.micro` | Free tier eligible; otherwise about $0.01 per hour |
| CodeBuild | Free tier covers 100 build minutes per month; each build takes about 1 minute |
| CodePipeline (V2) | Charged per action-execution minute, with a monthly free allowance. A lab run costs a few cents at most. |
| CodeDeploy to EC2 | Free |
| S3 (artifacts) | A few KB; negligible |

Do [5-cleanup.md](5-cleanup.md) at the end so nothing keeps running.

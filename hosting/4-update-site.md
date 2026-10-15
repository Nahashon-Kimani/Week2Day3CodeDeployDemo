# Part 4 — Update the Site: Blue → Magenta

**Goal:** Change the site's colour scheme from blue to magenta, then ship it through your pipeline.

**Flow:** Update colours → Push to GitHub → Retry build (CodeBuild) → Retry deployment (CodeDeploy)

---

## Step 1 — Update the colours

The blue (`#06BBCC`) is set in two files: `css/style.css` and `css/bootstrap.min.css`.

Open Git Bash (or a terminal) in your project folder and run this command. It finds each blue value in both files and replaces it with the matching magenta value.

```bash
cd ~/Desktop/elearning-cicd

sed -i \
  -e 's/#06BBCC/#D1208A/g' \
  -e 's/6,187,204/209,32,138/g' \
  -e 's/#F0FBFC/#FCF0F7/g' \
  -e 's/#2bc5d4/#D8429C/g' \
  -e 's/#1fc2d1/#D6379A/g' \
  -e 's/#38c9d6/#DA4FA4/g' \
  -e 's/5,159,173/178,27,117/g' \
  -e 's/#0596a3/#A71A6E/g' \
  -e 's/#83dde6/#E890C5/g' \
  css/style.css css/bootstrap.min.css
```

> **Mac:** change the first line to `sed -i '' \`.

Open `index.html` in your browser to preview it. Buttons, icons and headings should now be magenta.

---

## Step 2 — Push to GitHub

```bash
git add css/
git commit -m "Change colour scheme from blue to magenta"
git push
```

---

## Step 3 — Retry the build in CodeBuild

1. Open **CodeBuild** → **Build projects** → `elearning-build`.
2. Open the **Build history** tab, select your last build, and click **Retry build**.
3. Wait until the status is **Succeeded**. CodeBuild replaces `elearning-artifact.zip` in S3 with a new zip of your updated code.

> If you enabled the webhook in Part 2, a build may already have started when you pushed. If so, just wait for it to finish.

---

## Step 4 — Retry the deployment in CodeDeploy

1. Open **CodeDeploy** → **Deployments**.
2. Click your last **Succeeded** deployment, then click **Retry deployment**.
3. Wait until every lifecycle event shows **Succeeded**.

The retry deploys from the same S3 location, which now holds the new zip from Step 3.

> ⚠️ Only retry the deployment **after** the build has finished. If you retry too early, the old zip is deployed and the site stays blue.

---

## Step 5 — Check the live site

1. Open `http://<public-ip>` and press **Ctrl+F5** (Mac: **Cmd+Shift+R**) to force a full reload. Without it, the browser may show the old cached colours.
2. The site should now be magenta. 🎉

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Site is still blue after a successful deployment | Browser cache. Press **Ctrl+F5**, or open the site in a private window. |
| Still blue after a hard refresh | The deployment ran before the build finished. Wait for the build to succeed, then retry the deployment again. |
| Deployment fails | Open the deployment → **View events** and see the [3-codedeploy.md](3-codedeploy.md) troubleshooting table. |

✅ **Done.** When the class is over: [5-cleanup.md](5-cleanup.md)

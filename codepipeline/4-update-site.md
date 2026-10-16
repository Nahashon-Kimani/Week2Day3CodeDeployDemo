# Part 4 — Update the Site with Just a `git push`

**Goal:** Change the site from blue to magenta, push, and let the pipeline do the rest. Then roll it back the same way.

**Flow:** Update colours → `git push` → *(pipeline: Source → Build → Deploy)* → check the live site

> Compare this with doing it by hand: without a pipeline you'd have to start the build, wait for it to finish, then create the deployment yourself. Here, `git push` is the only command.

---

## Step 1 — Update the colours

The blue (`#06BBCC`) is set in two files: `css/style.css` and `css/bootstrap.min.css`.

In Git Bash (or a terminal), run this command from your project folder. It finds each blue value in both files and replaces it with the matching magenta value.

```bash
cd ~/Desktop/elearning-pipeline

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

That's the last command you need to run.

---

## Step 3 — Watch the pipeline

1. Open **CodePipeline** → `elearning-pipeline-<yourname>`.
2. Within a few seconds a new execution starts. Its **Source** stage shows your commit message, *Change colour scheme from blue to magenta*.
3. Wait for **Source ✔ → Build ✔ → Deploy ✔** (about 3–4 minutes).

> **Execution history** (left menu, or the button at the top) lists every run, with its trigger, commit and result.

---

## Step 4 — Check the live site

1. Open `http://<public-ip>` and press **Ctrl+F5** (Mac: **Cmd+Shift+R**) to force a full reload. Browsers cache CSS, so a normal refresh can still show blue.
2. The site should now be magenta. 🎉
3. Open `http://<public-ip>/build-info.txt`. The commit should match the output of `git log -1 --format=%H`.

---

## Step 5 (optional) — Roll back to blue

A bad release is undone the same way it was shipped: through Git and the pipeline, never by editing files on the server.

```bash
git revert HEAD --no-edit     # creates a new commit that undoes the colour change
git push
```

Watch the pipeline run again, then hard-refresh the site. It's blue again, and your Git history records both the change and the rollback.

---

## Step 6 (optional) — See a failing stage stop a release

A pipeline only deploys code that passes every earlier stage. Prove it by breaking the build on purpose:

1. Rename `appspec.yml` to `appspec.yaml`, then commit and push.
2. The **Build** stage fails at `test -f appspec.yml` (the check in `buildspec.yml`'s `pre_build` phase).
3. The **Deploy** stage never runs, so the live site is unaffected. Refresh it to check.
4. Rename the file back to `appspec.yml`, then commit and push. The pipeline goes green again.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Nothing happens after `git push` | Check that you pushed to `main` (`git branch` shows `* main`), and that the pipeline's Source stage uses the `main` branch. Click **Release change** to start a run by hand. |
| Pipeline succeeded, but the site is still blue | Browser cache. Press **Ctrl+F5** or open a private window. |
| Some parts are still blue | A replacement was missed. Run `grep -i "06BBCC" css/*.css`, fix whatever it finds, then commit and push. |
| Two executions appear after quick pushes | This is normal. Depending on the pipeline's execution mode, either the older run is marked *Superseded* or the newer one waits in a queue. Either way, the latest commit ends up live. |
| A stage failed | Click **View details** on it and see the troubleshooting table in [3-codepipeline.md](3-codepipeline.md). |

✅ **Done.** When the class is over: [5-cleanup.md](5-cleanup.md)

# Part 4 — Update the Site: Blue → Magenta

**Goal:** Make a real change to the website, change the colour scheme from blue to magenta, and ship it through the pipeline you built: commit → push → CodeBuild → S3 → CodeDeploy → EC2.

**Lab flow:** **GitHub** → **CodeBuild** → **S3 (artifact)** → **CodeDeploy** → **EC2 (Apache)**

> Before you start, the site from Part 3 should be live at `http://<public-ip>` with its blue theme. Take a screenshot so you can compare before and after.

---

## Where the colours live

The site's colours are defined in two stylesheets in the `css/` folder:

| File | What it controls |
|---|---|
| `css/style.css` | The template's own styles. The theme colours are variables at the top of the file. |
| `css/bootstrap.min.css` | Bootstrap, which the template has customised with the same blue. It controls `btn-primary`, `text-primary`, `bg-primary`, link hovers and form focus outlines. |

Open `css/style.css`. The first lines are:

```css
:root {
    --primary: #06BBCC;   /* blue: buttons, icons, headings, navbar highlight */
    --light: #F0FBFC;     /* very pale blue: section backgrounds */
    --dark: #181d38;      /* dark navy: footer and text (we keep this) */
}
```

Changing only these variables isn't enough: `bootstrap.min.css` has the same blue hard-coded in it about 50 times. That's why we replace the colour values in **both** files.

### Colour map

| Used for | Blue (old) | Magenta (new) |
|---|---|---|
| Main colour | `#06BBCC` | `#D1208A` |
| Main colour, as RGB (glows and shadows) | `6,187,204` | `209,32,138` |
| Light background | `#F0FBFC` | `#FCF0F7` |
| Button hover background | `#2bc5d4` | `#D8429C` |
| Button hover border | `#1fc2d1` | `#D6379A` |
| Button pressed | `#38c9d6` | `#DA4FA4` |
| Button focus shadow (RGB) | `5,159,173` | `178,27,117` |
| Link hover | `#0596a3` | `#A71A6E` |
| Form field focus border | `#83dde6` | `#E890C5` |

---

## Step 1 — Start from an up-to-date, clean repo

Open Git Bash (or a terminal) in your project folder:

```bash
cd ~/Desktop/elearning-cicd
git status
git pull
```

- `git status` should say *nothing to commit, working tree clean*. If it doesn't, commit or discard your earlier changes first.
- `git pull` fetches anything already on GitHub that you don't have locally.

---

## Step 2 — Change the colours

Choose **one** option.

### Option A — One command (Git Bash on Windows, or Linux)

This runs every replacement in the colour map on both stylesheets in one go. `sed -i` edits the files in place; each `-e` is one *find/replace* pair.

```bash
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

> **Mac:** change the first line to `sed -i '' \` (macOS `sed` needs an empty string after `-i`).

### Option B — VS Code Find and Replace

1. Press **Ctrl+Shift+H** (Mac: **Cmd+Shift+H**) to open **Replace in Files**.
2. Click **…** (*Toggle Search Details*) and set **files to include** to `css/*.css`.
3. For each row of the colour map: type the old value in **Search**, the new value in **Replace**, then click **Replace All** (the icon next to the Replace box).
4. Do all 9 rows, then save with **Ctrl+K S** (*Save All*).

---

## Step 3 — Check your changes locally

**3.1 Confirm no blue is left.** This searches both files for the three main blue values. No output means every one was replaced.

```bash
grep -i -n "06BBCC\|F0FBFC\|6,187,204" css/style.css css/bootstrap.min.css
```

**3.2 Confirm magenta is in.** You should see `#D1208A` at the top of `style.css`.

```bash
head -6 css/style.css
```

**3.3 Preview in your browser.** Double-click `index.html` in File Explorer (or Finder) to open it. The buttons, icons, navbar highlight and headings should now be magenta. Check `about.html` and `contact.html` too: click inside a contact form field to see the magenta focus outline.

**3.4 Review the diff.** Only the two CSS files should be listed.

```bash
git status
git diff --stat
```

---

## Step 4 — Commit and push

```bash
git add css/style.css css/bootstrap.min.css
git commit -m "Change colour scheme from blue to magenta"
git push
```

📝 Note your commit ID: run `git log -1 --format=%h` → `__________`

---

## Step 5 — Build with CodeBuild

- **If you enabled the webhook** in Part 2, a build has already started. Open **CodeBuild** → `elearning-build` → **Build history**.
- **If not**, open the project and click **Start build**.

Wait for **Succeeded**, then confirm a fresh zip is in S3:

```bash
aws s3 ls s3://<your-bucket>/
```

`elearning-artifact.zip` should be a single file with a timestamp from just now.

---

## Step 6 — Deploy with CodeDeploy

1. **CodeDeploy** → **Applications** → `elearning-app` → `elearning-dg` → **Create deployment**.
2. Use exactly the same settings as Part 3, Step 7:
   - **Revision location:** `s3://<your-bucket>/elearning-artifact.zip` (no trailing `/`)
   - **Revision file type:** `.zip`
   - **Additional deployment behavior settings:** *Overwrite the content*
3. Click **Create deployment** and wait for every lifecycle event to show **Succeeded**.

CLI alternative:

```bash
aws deploy create-deployment \
  --application-name elearning-app \
  --deployment-group-name elearning-dg \
  --s3-location bucket=<your-bucket>,key=elearning-artifact.zip,bundleType=zip \
  --file-exists-behavior OVERWRITE
```

---

## Step 7 — Verify the live site

1. Open `http://<public-ip>` and press **Ctrl+F5** (Mac: **Cmd+Shift+R**) to force a full reload. Browsers cache CSS files, so a normal refresh can still show the old blue.
2. The site should now be magenta. Compare it with your "before" screenshot.
3. Open `http://<public-ip>/build-info.txt`. The **Commit** line should start with the commit ID you noted in Step 4.

✅ You've shipped a change through the full CI/CD pipeline.

---

## Optional — Roll back to blue

Bad release? Undo it the same way you shipped it: through Git and the pipeline, never by editing files on the server.

```bash
git revert HEAD --no-edit     # creates a new commit that undoes the colour change
git push
```

Then repeat Steps 5–7. The site goes back to blue, and the Git history records both the change and the rollback.

> You can also click **Redeploy** on an earlier successful deployment in CodeDeploy. Because each build overwrites the same S3 key, that only restores blue if bucket versioning is on and you deploy the older object version.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Live site is still blue, but the deployment succeeded | Browser cache. Press **Ctrl+F5**, or open the site in a private window. |
| `build-info.txt` shows the old commit | The deployment used an old zip. Check that the build finished **before** you created the deployment, then deploy again. |
| Some buttons or links are still blue | A replacement was missed. Run the `grep` in Step 3.1, fix whatever it finds, then commit, push and redeploy. |
| `git push` is rejected with *fetch first* | Someone (or you, on GitHub) changed the repo. Run `git pull --rebase`, then push again. |
| Step 3.1 finds nothing, but the local preview is still blue | You edited a different copy of the project. Run `pwd` and check you're in `elearning-cicd`. |
| Deployment fails | Same causes as Part 3. Open the failed deployment → **View events** and see the [3-codedeploy.md](3-codedeploy.md) troubleshooting table. |

✅ **Done.** When the class is over: [5-cleanup.md](5-cleanup.md)

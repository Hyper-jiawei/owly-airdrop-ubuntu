---
name: github-release
description: GitHub project release checklist, one-line install setup, CI/CD, and search optimization workflow for macOS menu-bar / Swift projects.
---

# GitHub Release & Discoverability Workflow

Use this skill whenever the user mentions releasing a new version, publishing to GitHub, setting up one-line install, or improving repo discoverability.

## When to Trigger

- User says "release", "publish", "发布", "发版", "打包发布"
- User says "install", "安装", "one-line install"
- User asks about GitHub search visibility, topics, discoverability
- User sets up a new macOS / Swift project repo

---

## 1. One-Line Install Setup

### 1a. `install.sh` at repo root

Create `install.sh` that downloads from GitHub Releases:

```bash
#!/bin/bash
set -e

REPO="<owner>/<repo>"
APP_NAME="<AppName>"

VERSION="${1:-latest}"
if [ "$VERSION" = "latest" ]; then
    echo "==> Fetching latest version..."
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [ -n "$VERSION" ] || { echo "Error: could not determine latest version"; exit 1; }
fi

VERSION_NUM="${VERSION#v}"
ZIP_URL="https://github.com/$REPO/releases/download/$VERSION/<AppName>-v${VERSION_NUM}.zip"
TMP_DIR=$(mktemp -d)

echo "==> Downloading..."
curl -fsSL --progress-bar -o "$TMP_DIR/$APP_NAME.zip" "$ZIP_URL"
echo "==> Extracting..."
unzip -oq "$TMP_DIR/$APP_NAME.zip" -d "$TMP_DIR"

if [ -d "/Applications/$APP_NAME.app" ]; then
    echo "==> Removing old version..."
    sudo rm -rf "/Applications/$APP_NAME.app"
fi

echo "==> Installing to /Applications..."
sudo cp -R "$TMP_DIR/$APP_NAME.app" "/Applications/"
sudo chown -R "$(whoami):staff" "/Applications/$APP_NAME.app"

echo "==> Launching..."
open "/Applications/$APP_NAME.app"
rm -rf "$TMP_DIR"
echo "  $APP_NAME $VERSION installed and running"
```

**Check**: `chmod +x install.sh`

### 1b. README install section

Add one-liner to README install section:

```markdown
### One-Line Install (Recommended)

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | bash
\`\`\`
```

---

## 2. GitHub Actions Release Workflow

### 2a. Create `.github/workflows/release.yml`

```yaml
name: Build and Release

on:
  push:
    tags:
      - "v*"
  workflow_dispatch:
    inputs:
      version:
        description: "Version tag (e.g. v1.2.0)"
        required: true

permissions:
  contents: write

jobs:
  build:
    runs-on: macos-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Determine version
        id: version
        run: |
          if [ "${{ github.event_name }}" = "push" ]; then
            echo "VERSION=${GITHUB_REF#refs/tags/}" >> "$GITHUB_OUTPUT"
          else
            echo "VERSION=${{ inputs.version }}" >> "$GITHUB_OUTPUT"
          fi

      - name: Build app bundle
        run: |
          chmod +x scripts/build.sh
          bash scripts/build.sh

      - name: Create zip for release
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          VERSION_NUM="${VERSION#v}"
          ditto -c -k --keepParent build/<AppName>.app "build/<AppName>-v${VERSION_NUM}.zip"

      - name: Upload to release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.version.outputs.version }}
          files: build/<AppName>-v*.zip
          fail_on_unmatched_files: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Key check**: zip filename in step 3 MUST match the URL pattern in `install.sh`.

### 2b. Release workflow

```bash
# 1. Bump version in Info.plist (CFBundleVersion + CFBundleShortVersionString)
# 2. Commit
git add resources/Info.plist
git commit -m "chore: bump version to X.Y.Z"

# 3. Tag and push
git tag vX.Y.Z
git push origin main
git push origin vX.Y.Z

# 4. Verify CI
gh run list --workflow=release.yml --limit=1
gh release view vX.Y.Z
```

---

## 3. GitHub Search Optimization Checklist

**This is the part most often forgotten. Run through every item.**

### 3a. Topics (set via API)

Use `gh api` to set topics. Pick 10-15 relevant ones:

```
macos macos-app menubar swift swiftui
<domain-specific> <domain-specific> <domain-specific>
productivity utility tool open-source
```

For Owly specifically: `anti-sleep` `sleep-prevention` `caffeinate` `iokit` `pmset`

Command:
```bash
gh api -X PUT repos/<owner>/<repo>/topics \
  -H "Accept: application/vnd.github+json" \
  -f 'names[]=topic1' -f 'names[]=topic2' ...
```

### 3b. Description (bilingual)

If the project has Chinese users, make description bilingual (max 350 chars):

```bash
gh repo edit <owner>/<repo> --description "<English description>。<Chinese description>。"
```

**Include high-search-volume keywords** in the description:
- What it does (verb + object): "keep Mac awake", "prevent sleep", "防睡眠"
- Platform: "macOS", "menu-bar"
- Use cases: "compiles", "AI agents", "长任务"
- Key differentiator: "free", "open-source"

### 3c. README images (absolute raw URLs)

**Relative paths break on GitHub.** Always use raw URLs for README images:

```markdown
<!-- WRONG -->
![screenshot](resources/screenshot.png)

<!-- RIGHT -->
![screenshot](https://raw.githubusercontent.com/<owner>/<repo>/main/resources/screenshot.png)
```

### 3d. Bilingual README (optional but recommended)

If the project targets Chinese + English users:
- `README.md` — primary language (e.g., Chinese) + language switcher at top
- `README_EN.md` — English translation + language switcher at top

Language switcher format:
```markdown
**中文** | [English](README_EN.md)
```

---

## 4. Pre-Release Punchlist

Before tagging a release, verify each item:

- [ ] `Info.plist` version bumped (`CFBundleVersion` + `CFBundleShortVersionString`)
- [ ] App builds clean: `./scripts/build.sh` exits 0
- [ ] `install.sh` zip URL pattern matches `.github/workflows/release.yml` output filename
- [ ] `README.md` has one-line install command
- [ ] GitHub topics set (≥10)
- [ ] Repo description is bilingual (if applicable)
- [ ] README images use `raw.githubusercontent.com` URLs
- [ ] `README_EN.md` exists and is up-to-date (if applicable)
- [ ] Language switcher links present in both READMEs (if applicable)

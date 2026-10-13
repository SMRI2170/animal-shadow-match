# Publish this project to GitHub

Target account confirmed from GitHub connection: **SMRI2170**.
Suggested new repository: **animal-shadow-match** (initially **Private**; make Public after checking content and licensing).

The available GitHub connector cannot directly create a **new repository**, so the repository must be created by the owner once.

1. Open https://github.com/new
2. Select account `SMRI2170` and name `animal-shadow-match`.
3. Select **Private**. **Do not** tick the options that pre-create a README, `.gitignore`, or license (they already exist locally or have not been selected).
4. Unzip the supplied project and open a shell in the root folder.
5. Run:

```bash
git init -b main
git add .
git commit -m "chore: initialize animal shadow match"
git remote add origin https://github.com/SMRI2170/animal-shadow-match.git
git push -u origin main
```

GitHub authentication may be requested by your local Git credentials. On Windows use PowerShell or Git Bash; on macOS use Terminal. If `git init -b main` is unsupported, run `git init` then `git branch -M main`.

## Issue import (optional, one time)

The issue descriptions live in `docs/issues/01-*.md` etc. Install/authenticate GitHub CLI (`gh auth login`) and run `bash scripts/create_issues.sh` from the repository root on macOS/Linux/Git Bash, or `./scripts/create_issues.ps1` from PowerShell. It will create one issue per file. Avoid rerunning: duplicates are possible. An issue template is also included for future manually added work.

## Starting local Flutter

```bash
flutter create --project-name animal_shadow_match --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter run
```

**Important:** Initial zip does **not** include native Android/iOS platform folders. After generating Android via Flutter, commit those generated project files separately; review package ID/application ID before publishing. Do not use `flutter create --overwrite`, as that can overwrite prototype Dart files.

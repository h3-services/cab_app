# Version Control Guide for Cap App

## ✅ Current Status
- **Git**: Installed (v2.45.2)
- **Repository**: Already initialized
- **Remote**: https://github.com/h3-services/cab_app.git
- **Current Branch**: test-branch
- **App Version**: 1.0.1+2

## 📋 Daily Workflow

### 1. Check What Changed
```bash
git status
```

### 2. Stage Your Changes
```bash
# Add all changes
git add .

# Or add specific files
git add lib/screens/profile/wallet_screen.dart
```

### 3. Commit Your Changes
```bash
git commit -m "feat: add wallet transaction history"
```

**Commit Message Conventions:**
- `feat:` - New feature
- `fix:` - Bug fix
- `chore:` - Maintenance tasks
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `style:` - Code formatting

### 4. Push to GitHub
```bash
git push
```

### 5. Pull Latest Changes (Before Starting Work)
```bash
git pull
```

## 🔄 Branch Management

### Create New Feature Branch
```bash
git checkout -b feature/payment-integration
```

### Switch Between Branches
```bash
git checkout main
git checkout test-branch
```

### Merge Branch to Main
```bash
git checkout main
git merge test-branch
git push
```

## 📱 App Version Updates

### For Minor Updates (Bug Fixes)
Edit `pubspec.yaml`:
```yaml
version: 1.0.2+3  # 1.0.2 = version, 3 = build number
```

### For Major Updates (New Features)
```yaml
version: 1.1.0+4
```

### For Breaking Changes
```yaml
version: 2.0.0+5
```

After updating version:
```bash
git add pubspec.yaml
git commit -m "chore: bump version to 1.0.2+3"
git push
```

## 🚫 Files Already Ignored (.gitignore)

The following are automatically excluded:
- `build/` - Build artifacts
- `.dart_tool/` - Dart tools cache
- `android/.gradle/` - Android Gradle cache
- `android/.kotlin/` - Kotlin build files
- `ios/Pods/` - iOS dependencies
- `.packages` - Package cache
- Firebase config files (for security)

## 🔧 Useful Commands

### View Commit History
```bash
git log --oneline -10
```

### Undo Last Commit (Keep Changes)
```bash
git reset --soft HEAD~1
```

### Discard All Local Changes
```bash
git reset --hard HEAD
```

### View Differences
```bash
git diff
```

### Create Tag for Release
```bash
git tag -a v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1
```

## 🎯 Best Practices

1. **Commit Often**: Make small, focused commits
2. **Pull Before Push**: Always pull latest changes before pushing
3. **Meaningful Messages**: Write clear commit messages
4. **Test Before Commit**: Ensure app runs without errors
5. **Never Commit**: Passwords, API keys, or sensitive data
6. **Branch Strategy**: Use feature branches for new features

## 🆘 Common Issues

### Merge Conflicts
```bash
# Edit conflicted files manually
git add .
git commit -m "fix: resolve merge conflicts"
```

### Forgot to Pull Before Changes
```bash
git stash
git pull
git stash pop
```

### Accidentally Committed Wrong Files
```bash
git reset HEAD~1
# Fix the files
git add .
git commit -m "correct commit message"
```

## 📦 Release Checklist

Before releasing to Play Store:

1. ✅ Update version in `pubspec.yaml`
2. ✅ Test app thoroughly
3. ✅ Commit all changes
4. ✅ Create release tag
5. ✅ Push to GitHub
6. ✅ Build release APK/AAB
7. ✅ Upload to Play Store

```bash
# Complete release workflow
git add pubspec.yaml
git commit -m "chore: release version 1.0.2"
git tag -a v1.0.2 -m "Release 1.0.2 - Bug fixes and improvements"
git push origin test-branch
git push origin v1.0.2
```

## 🔗 Quick Reference

| Task | Command |
|------|---------|
| Check status | `git status` |
| Stage all | `git add .` |
| Commit | `git commit -m "message"` |
| Push | `git push` |
| Pull | `git pull` |
| New branch | `git checkout -b branch-name` |
| Switch branch | `git checkout branch-name` |
| View history | `git log --oneline` |
| Undo changes | `git reset --hard HEAD` |

---

**Repository**: https://github.com/h3-services/cab_app.git
**Current Branch**: test-branch
**Last Updated**: Version 1.0.1+2

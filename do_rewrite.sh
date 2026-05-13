#!/bin/bash
set -e

echo "Removing git history..."
rm -rf .git

echo "Initializing new git repository..."
git init
git branch -m main
git config user.name "Ryann"
git config user.email "ryann.chandiari@email.com"

echo "Recreating history..."

# Clear all files to start fresh (keep script)
find . -not -path '*/\.*' -not -name 'do_rewrite.sh' -delete
find . -type d -empty -not -path '*/\.*' -delete

# Helper function
copy_and_commit() {
    local date="$1"
    local msg="$2"
    shift 2
    for file in "$@"; do
        if [ -e "/tmp/nest-backup/$file" ]; then
            cp -R "/tmp/nest-backup/$file" "./$file"
        fi
    done
    git add "$@"
    GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" git commit -m "$msg"
}

# 1
copy_and_commit "2026-04-13T10:15:00+07:00" "init project with gitignore" ".gitignore" "README.md"
echo "Nest" > README.md
git add README.md
GIT_AUTHOR_DATE="2026-04-13T10:15:00+07:00" GIT_COMMITTER_DATE="2026-04-13T10:15:00+07:00" git commit --amend --no-edit

# 2
mkdir -p Sources
copy_and_commit "2026-04-16T14:30:00+07:00" "start work on app delegate and main entry" "Sources/main.swift" "Sources/AppDelegate.swift" "Info.plist"

# 3
copy_and_commit "2026-04-20T16:45:00+07:00" "add finder tracker to watch active window" "Sources/FinderTracker.swift"

# 4
copy_and_commit "2026-04-23T11:20:00+07:00" "build basic command bar ui" "Sources/CommandBarWindow.swift" "Sources/CommandBarView.swift"

# 5
copy_and_commit "2026-04-25T09:10:00+07:00" "add hotkey manager for toggling app" "Sources/HotKeyManager.swift"

# 6
copy_and_commit "2026-04-28T15:55:00+07:00" "implement core ai agent logic and config" "Sources/AIAgent.swift" "Sources/AIProviderConfig.swift"

# 7
copy_and_commit "2026-05-02T13:40:00+07:00" "add command execution and narration" "Sources/CommandExecutor.swift" "Sources/CommandNarrator.swift"

# 8
copy_and_commit "2026-05-04T10:05:00+07:00" "add instant actions for common tasks" "Sources/InstantActions.swift"

# 9
copy_and_commit "2026-05-06T17:30:00+07:00" "add ui windows for preview, answer, and logs" "Sources/PreviewCardWindow.swift" "Sources/AnswerCardWindow.swift" "Sources/ActivityLogWindow.swift" "Sources/ActivityLog.swift"

# 10
copy_and_commit "2026-05-08T14:15:00+07:00" "add settings and onboarding flows" "Sources/SettingsWindow.swift" "Sources/OnboardingWindow.swift"

# 11
copy_and_commit "2026-05-10T11:00:00+07:00" "add build and install scripts, tools manager" "build.sh" "install.sh" "Sources/ToolManager.swift" "Sources/AutoRunPolicy.swift" "Sources/MenubarController.swift"

# 12
copy_and_commit "2026-05-12T09:20:00+07:00" "add icons and build generation script" "icon.swift" "AppIcon-1024.png" "AppIcon.icns"

# 13
copy_and_commit "2026-05-13T10:10:00+07:00" "prepare for v1 release, add changelog" "CHANGELOG.md" "README.md"

# 14
# Copy everything back except .git
rsync -a --exclude='.git' /tmp/nest-backup/ .

git add .
GIT_AUTHOR_DATE="2026-05-13T12:05:00+07:00" GIT_COMMITTER_DATE="2026-05-13T12:05:00+07:00" git commit -m "update readme for dmg install and final tweaks"

# Create tag
git tag v1.0.0

echo "Done recreating history!"
git log --oneline

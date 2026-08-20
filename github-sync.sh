#!/bin/bash

echo "========================================="
echo "[OmniRoute] Starting with Full GitHub Sync..."
echo "========================================="

BACKUP_REPO_NAME="OmniRoute-Data-Backup"
GITHUB_USER="anurag008w"
DATA_DIR="/app/data"

mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

# Configure Git
git config --global user.name "OmniRouter Auto-Sync"
git config --global user.email "sync@omnirouter.local"
git config --global init.defaultBranch main
git config --global pull.rebase false

if [ -n "$GITHUB_PAT" ]; then
    echo "[GitHub Sync] Checking backup repository '$BACKUP_REPO_NAME'..."
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_PAT" "https://api.github.com/repos/$GITHUB_USER/$BACKUP_REPO_NAME")
    
    if [ "$STATUS_CODE" -eq 404 ]; then
        echo "[GitHub Sync] Creating private backup repo '$BACKUP_REPO_NAME'..."
        curl -s -X POST -H "Authorization: token $GITHUB_PAT" -d "{\"name\":\"$BACKUP_REPO_NAME\", \"private\": true}" https://api.github.com/user/repos
        if [ ! -d ".git" ]; then
            git init
            git remote add origin "https://${GITHUB_PAT}@github.com/${GITHUB_USER}/${BACKUP_REPO_NAME}.git"
            git checkout -b main 2>/dev/null || true
        fi
    else
        echo "[GitHub Sync] Backup repository found! Restoring previous data..."
        if [ ! -d ".git" ]; then
            git init
            git remote add origin "https://${GITHUB_PAT}@github.com/${GITHUB_USER}/${BACKUP_REPO_NAME}.git"
            git fetch origin main 2>/dev/null || true
            git checkout -f main 2>/dev/null || true
            echo "[GitHub Sync] ✅ Previous data restored successfully!"
        fi
    fi
else
    echo "[GitHub Sync] ⚠️ GITHUB_PAT is not set! Running without cloud backup."
fi

echo "-----------------------------------------"
echo "[OmniRoute] Starting main server on port ${PORT:-20128}..."
echo "-----------------------------------------"
cd /app
node dev/run-standalone.mjs &
APP_PID=$!

do_sync() {
    if [ -z "$GITHUB_PAT" ]; then
        return
    fi
    cd "$DATA_DIR"
    if [ ! -d ".git" ]; then
        git init
        git remote add origin "https://${GITHUB_PAT}@github.com/${GITHUB_USER}/${BACKUP_REPO_NAME}.git"
        git checkout -b main 2>/dev/null || true
    else
        git remote set-url origin "https://${GITHUB_PAT}@github.com/${GITHUB_USER}/${BACKUP_REPO_NAME}.git"
    fi

    if [ -n "$(git status --porcelain)" ]; then
        echo "[GitHub Sync] Changes detected. Backing up all files to GitHub..."
        git add -A
        git commit -m "Auto-backup: $(date +'%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
        git push -u origin main 2>/dev/null || echo "[GitHub Sync] Push failed, will retry next interval."
    fi
}

trap 'echo "[GitHub Sync] Shutdown received! Performing final sync..."; do_sync; kill $APP_PID 2>/dev/null; exit 0' SIGTERM SIGINT

while true; do
    if ! kill -0 "$APP_PID" 2>/dev/null; then
        echo "[OmniRoute] ❌ Main application exited. Terminating container."
        wait "$APP_PID"
        exit $?
    fi
    sleep 30 &
    wait $!
    do_sync
done

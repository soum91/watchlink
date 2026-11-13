#!/bin/sh
set -eu
cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
gh auth status
if [ ! -d .git ]; then git init -b main; fi
git config user.name 'WatchLink contributors'
git config user.email 'watchlink@users.noreply.github.com'
git add .
if ! git diff --cached --quiet; then git commit -m 'Add WatchLink pairing access research probe and release pipeline'; fi
if gh repo view soum91/watchlink >/dev/null 2>&1; then
    if ! git remote get-url origin >/dev/null 2>&1; then git remote add origin https://github.com/soum91/watchlink.git; fi
    git push -u origin main
else
    gh repo create soum91/watchlink --public --source . --remote origin --push --description 'Experimental Watch pairing access research'
fi
gh workflow run release.yml --ref main

# Plugins

Drop `.jar` plugin files in this folder, then restart the server (`.\start.ps1`).

Popular starting points:
- EssentialsX - basic player commands (home, tp, warp)
- LuckPerms - permissions and ranks
- WorldEdit / WorldGuard - building and protected regions
- Plan - server and player statistics

First plugin inside each folder is loaded automatically by Paper. Keep plugin jars out
of git (`.gitignore` ignores everything here except this file) - they are big and can be
re-downloaded.

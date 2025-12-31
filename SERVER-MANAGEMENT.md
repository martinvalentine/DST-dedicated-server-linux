# DST Server Quick Guide

## Start Server

**Interactive Menu (Recommended):**
```bash
./dst-server-manager.sh
```

**First Time Setup:**
```bash
./dst-server-setup.sh
```

## Fix Workshop Mod Downloads

If mods fail with "Staging library folder not found":
```bash
./scripts/fix-steam-workshop.sh
```
Then restart the server.

## Stop Server

**From Terminal Windows:** Press `Ctrl+C` in each window

**Command Line:**
```bash
pkill -f dontstarve_dedicated_server
```

## Check Status

```bash
ps aux | grep dontstarve_dedicated_server
```

## View Logs

```bash
tail -f ~/.klei/DoNotStarveTogether/MyDediServer/Master/server_log.txt
tail -f ~/.klei/DoNotStarveTogether/MyDediServer/Caves/server_log.txt
```

## Console Commands

Type in server terminal:
- `c_shutdown()` - Stop server
- `c_save()` - Save world
- `c_announce("msg")` - Send message to players

## File Structure

```
.
├── dst-server-setup.sh      # First-time setup wizard
├── dst-server-manager.sh    # Server management menu
├── scripts/
│   ├── fix-steam-workshop.sh    # Fix mod download issues
│   └── start-dst-terminals.sh   # Quick start helper
└── test/                    # Test files
```

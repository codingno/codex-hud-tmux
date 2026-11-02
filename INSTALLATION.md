# Installation (tmux + Catppuccin) — instructions for an AI agent

Goal: install the `codex-hud-tmux` plugin on a machine that already runs tmux
with the **catppuccin/tmux** theme (TPM-managed, legacy `@catppuccin_status_modules_right` API with
`~/.tmux/custom/*.sh` custom modules). Result: a `codex` module in the right
status bar (`5h 99% ↻04:07 │ wk 24% ↻Nov 04 13:38`) and a `prefix + C` popup.

Follow the steps in order. Do not skip the verification section.

## 0. Prerequisites — verify first

```sh
tmux -V                    # need 3.2+
python3 --version          # 3.9+
codex --version            # Codex CLI must be on PATH and logged in (`codex login`)
ls ~/.tmux/plugins/tpm     # TPM installed
grep -n catppuccin ~/.tmux.conf
```

- The HUD gets live limits by running `codex app-server` (needs `codex` on
  `PATH` of the tmux server and a valid `~/.codex/auth.json`). If `codex` is
  missing or logged out it falls back to `~/.codex/sessions/**` rollouts,
  which may be stale.
- If catppuccin uses the newer v2 config (`@catppuccin_flavor`, `#{E:@catppuccin_status_*}`),
  this guide's module format does not apply; adapt the module accordingly or
  use the standalone method in `README.md`.

## 1. Place the plugin

Copy or clone this repo to a stable path. The examples use
`$HOME/personal/codex-hud-tmux`; if you choose another path, substitute it
everywhere below.

```sh
mkdir -p ~/personal
# copy the repo here (git clone <repo-url> ~/personal/codex-hud-tmux, or rsync/scp)
chmod +x ~/personal/codex-hud-tmux/codex-hud.tmux \
         ~/personal/codex-hud-tmux/scripts/codex-hud \
         ~/personal/codex-hud-tmux/scripts/codex-hud-status \
         ~/personal/codex-hud-tmux/scripts/poll
```

Smoke test (should print something like `5h 99% ↻04:07 │ wk 24% ↻Nov 04 13:38`,
may take ~5 s):

```sh
~/personal/codex-hud-tmux/scripts/codex-hud status --plain --refresh
```

## 2. Create the Catppuccin custom module

Catppuccin loads custom modules from `@catppuccin_custom_plugin_dir`. Create
`~/.tmux/custom/codex.sh` (the directory may already hold other modules; leave
them alone):

```sh
mkdir -p ~/.tmux/custom
cat > ~/.tmux/custom/codex.sh <<'EOF'
show_codex() {
  local index icon color text bin

  index=$1
  icon=$(get_tmux_option "@catppuccin_codex_icon" "")
  color=$(get_tmux_option "@catppuccin_codex_color" "$thm_blue")
  bin=$(get_tmux_option "@codex-hud-bin" "$HOME/personal/codex-hud-tmux/scripts/codex-hud-status")

  text="#(\"$bin\" plain)"

  build_status_module "$index" "$icon" "$color" "$text"
}
EOF
```

The function name must be `show_<module name>`; the module name `codex` is
what goes into `@catppuccin_status_modules_right`.

## 3. Edit `~/.tmux.conf`

Add these lines **before** `run '~/.tmux/plugins/tpm/tpm'`. Use absolute paths
(tmux does not expand `$HOME` inside `set -g` option values reliably, so write
the real home directory, e.g. `/Users/alice` or `/home/alice`).

```tmux
# Catppuccin custom modules
set -g @catppuccin_custom_plugin_dir "/ABS/HOME/.tmux/custom"
set -g @catppuccin_status_modules_right "application session codex"
#   ^ keep any modules you already had (e.g. pomodoro); just add `codex`

# Codex usage HUD: 5-hour + weekly rate-limit budget
set -g @codex-hud-bin "/ABS/HOME/personal/codex-hud-tmux/scripts/codex-hud-status"
set -g @codex-hud-interval "30"
set-environment -g CODEX_HUD_INTERVAL "30"
set-environment -g CODEX_HUD_STALE "600"
set-environment -g CODEX_HUD_WARN "50"
set-environment -g CODEX_HUD_CRIT "20"
set-environment -g CODEX_HUD_BAR_WIDTH "20"
bind-key C display-popup -E -w 60 -h 16 -T "Codex HUD" "\"/ABS/HOME/personal/codex-hud-tmux/scripts/codex-hud\" detail --wait"
```

Add this line **after** `run '~/.tmux/plugins/tpm/tpm'` (catppuccin truncates
`status-right` at 100 chars, which would cut the module off):

```tmux
set -g status-right-length 160
```

Notes:
- Do **not** also load `codex-hud.tmux` (the standalone entry point) — it would
  insert a duplicate module into `status-right`.
- `set-environment` lines are required: the status script reads options from
  `CODEX_HUD_*` env vars and never calls back into tmux (that would deadlock).
- If `prefix + C` is already bound to something else, change the key letter in
  `bind-key`.

## 4. Reload and verify

```sh
tmux source-file ~/.tmux.conf
```

If the status bar does not change, restart the server (`tmux kill-server`, then
start tmux again) because `set-environment` and module loading are most
reliable on a fresh server.

Verification checklist:

1. `tmux show-environment -g | grep CODEX_HUD` lists the 5 variables.
2. `tmux show-option -gqv status-right-length` prints `160`.
3. The right side of the status bar shows `5h NN% ↻HH:MM │ wk NN% ↻Mon DD HH:MM`
   within ~30 s (first render can show `codex: idle` until the first refresh).
4. `prefix + C` opens a popup titled "Codex HUD" with two bars and
   `Live from Codex account`; press any key to close it.
5. Debug if needed:
   ```sh
   ~/personal/codex-hud-tmux/scripts/codex-hud json
   ls -la "${TMPDIR:-/tmp}/codex-hud-$(id -u)/"   # cached status files
   ```

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Module missing | `codex` not in `@catppuccin_status_modules_right`, wrong `@catppuccin_custom_plugin_dir`, or `show_codex` not defined. Restart tmux server. |
| Shows `codex: idle` / old numbers | `codex` not on tmux's `PATH` or not logged in. Run `codex login`; confirm `which codex` from a tmux shell; fall back data comes from `~/.codex/sessions`. |
| Text cut off | `status-right-length` not set after `run tpm`. |
| Popup does nothing | Wrong absolute path in `bind-key`, or tmux < 3.2 (no `display-popup`). |
| Slow popup open | Normal: it spawns `codex app-server` (~3–5 s). |
| macOS `stat`/Linux | `codex-hud-status` handles both (`stat -f %m` / `stat -c %Y`). |

## Optional tuning

| Env var (set with `set-environment -g`) | Default | Meaning |
| --- | --- | --- |
| `CODEX_HUD_INTERVAL` | `30` | Seconds between cache refreshes |
| `CODEX_HUD_STALE` | `600` | Seconds before rollout data is considered stale |
| `CODEX_HUD_WARN` | `50` | Remaining % → yellow |
| `CODEX_HUD_CRIT` | `20` | Remaining % → red |
| `CODEX_HUD_BAR_WIDTH` | `20` | Popup bar width |

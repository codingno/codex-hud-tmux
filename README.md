# codex-hud.tmux

A [tmux](https://github.com/tmux/tmux) plugin that shows your Codex
rate-limit budget — the **5-hour** and **weekly** windows — directly in the
status line, with a detailed popup on demand.

```
 5h 72% ↻4h12m │ wk 88% ↻2d03h
```

It reads the newest Codex session rollout from `~/.codex/sessions/**` and
extracts the `token_count` event (which carries `rate_limits.primary` for the
5-hour window and `rate_limits.secondary` for the weekly window). No network
calls, no API keys, no Codex instrumentation.

## Requirements

- tmux 3.2+ (uses user options in formats and `display-popup`)
- python3 (ships with macOS and most Linux distributions)
- Codex CLI with a recent session in `~/.codex/sessions/`

## Installation (TPM)

```tmux
set -g @plugin 'yourname/codex-hud-tmux'
```

Then press `prefix + I`. If you are developing locally, point TPM at the path:

```tmux
set -g @plugin '/Users/you/personal/codex-hud-tmux'
```

Or load it manually at the end of `~/.tmux.conf`:

```tmux
run-shell /Users/you/personal/codex-hud-tmux/codex-hud.tmux
```

Reload tmux with `tmux source-file ~/.tmux.conf`.

## Usage

| Action | Default |
| --- | --- |
| Status-line module | appended to `status-right` |
| Detail popup | `prefix + C` |

The status module is inserted at the front of `status-right` as
`#("<plugin>/scripts/codex-hud-status" styled)`. The same string is stored in
the `@codex-hud-status` user option, which you can reference with
`#{E:@codex-hud-status}` if you want to move it:

```tmux
set -g status-right '#{E:@codex-hud-status} | %H:%M'
```

## Catppuccin integration

If you use [catppuccin/tmux](https://github.com/catppuccin/tmux), add a custom
module instead of using the standalone `codex-hud.tmux` entry point:

```bash
# ~/.tmux/custom/codex.sh
show_codex() {
  local index icon color text bin

  index=$1
  icon=$(get_tmux_option "@catppuccin_codex_icon" "")
  color=$(get_tmux_option "@catppuccin_codex_color" "$thm_blue")
  bin=$(get_tmux_option "@codex-hud-bin" "$HOME/personal/codex-hud-tmux/scripts/codex-hud-status")

  text="#(\"$bin\" plain)"

  build_status_module "$index" "$icon" "$color" "$text"
}
```

Then enable it and add the popup binding in `~/.tmux.conf`:

```tmux
set -g @codex-hud-bin "$HOME/personal/codex-hud-tmux/scripts/codex-hud-status"
set-environment -g CODEX_HUD_INTERVAL "30"
set-environment -g CODEX_HUD_STALE "600"
set-environment -g CODEX_HUD_WARN "50"
set-environment -g CODEX_HUD_CRIT "20"
set-environment -g CODEX_HUD_BAR_WIDTH "20"

set -g @catppuccin_status_modules_right "application session codex pomodoro"
bind-key C display-popup -E -w 60 -h 16 -T "Codex HUD" "\"$HOME/personal/codex-hud-tmux/scripts/codex-hud\" detail --wait"
```

`codex-hud-status plain` emits the unstyled text and is safe to run on every
redraw; the Catppuccin module supplies the colors and separators.

## Options

Set these in `~/.tmux.conf` **before** the plugin is loaded.

| Option | Default | Meaning |
| --- | --- | --- |
| `@codex-hud-interval` | `30` | Seconds between cache refreshes (min 5) |
| `@codex-hud-stale` | `600` | Seconds after which a session is considered stale and dimmed |
| `@codex-hud-warn` | `50` | Remaining % at or below which the module turns yellow |
| `@codex-hud-crit` | `20` | Remaining % at or below which the module turns red |
| `@codex-hud-bar-width` | `20` | Bar width in the detail popup |
| `@codex-hud-key` | `C` | Prefix key for the popup; set to `none` to disable |

```tmux
set -g @codex-hud-interval 15
set -g @codex-hud-warn 40
set -g @codex-hud-crit 15
set -g @codex-hud-key H
```

## How it works

1. `scripts/codex-hud-status` (bash) serves the cached string on status-line
   redraws and only invokes Python when the cache is older than
   `@codex-hud-interval`, keeping redraws cheap.
2. `scripts/codex-hud status` parses the newest rollout, writes the cache and
   prints the tmux-formatted string.
3. `scripts/codex-hud detail` re-reads the session and renders the ANSI popup
   (bars, reset countdowns, plan, thread name, context window usage).
4. `scripts/poll` keeps the cache warm in the background for the standalone
   `codex-hud.tmux` entry point.
5. `scripts/codex-hud json` dumps the parsed snapshot for debugging.

Options are passed to the status command through `CODEX_HUD_*` environment
variables (the plugin sets them with `set-environment -g`). The status command
never calls back into tmux, which avoids deadlocks while tmux is evaluating a
`#()` job.

When no active Codex session is found the module shows `codex: idle`. Older
sessions that predate `rate_limits` fall back to total token counts.

## Development

```sh
./scripts/codex-hud json     # inspect the parsed snapshot
./scripts/codex-hud status   # print the status string
./scripts/codex-hud detail   # print the popup view
```

## License

MIT

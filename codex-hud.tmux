#!/usr/bin/env bash
set -uo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUD="$CURRENT_DIR/scripts/codex-hud"

get_tmux_option() {
  local option="$1" default="$2" value
  value="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  if [ -n "$value" ]; then printf '%s' "$value"; else printf '%s' "$default"; fi
}

set_default() {
  local option="$1" default="$2"
  if [ -z "$(tmux show-option -gqv "$option" 2>/dev/null || true)" ]; then
    tmux set-option -gq "$option" "$default"
  fi
}

set_default "@codex-hud-interval" "30"
set_default "@codex-hud-stale" "600"
set_default "@codex-hud-warn" "50"
set_default "@codex-hud-crit" "20"
set_default "@codex-hud-bar-width" "20"

# Expose options to the status script without spawning tmux on every redraw.
tmux set-environment -g CODEX_HUD_INTERVAL "$(get_tmux_option @codex-hud-interval 30)"
tmux set-environment -g CODEX_HUD_STALE "$(get_tmux_option @codex-hud-stale 600)"
tmux set-environment -g CODEX_HUD_WARN "$(get_tmux_option @codex-hud-warn 50)"
tmux set-environment -g CODEX_HUD_CRIT "$(get_tmux_option @codex-hud-crit 20)"
tmux set-environment -g CODEX_HUD_BAR_WIDTH "$(get_tmux_option @codex-hud-bar-width 20)"

# Status module. tmux does not re-expand #() inside #{@user_option}, so the
# command is inserted into status-right directly. The option mirrors it for
# users who prefer to reference it via #{E:@codex-hud-status}.
hud_cmd="#(\"$CURRENT_DIR/scripts/codex-hud-status\" styled)"
tmux set-option -gq "@codex-hud-status" "$hud_cmd"

status_right="$(tmux show-option -gqv status-right 2>/dev/null || true)"
if [[ "$status_right" != *"$hud_cmd"* ]]; then
  tmux set-option -g status-right "$hud_cmd ${status_right}"
fi

key="$(get_tmux_option "@codex-hud-key" "C")"
if [ "$key" != "none" ]; then
  tmux bind-key "$key" display-popup -E -w 60 -h 16 -T "Codex HUD" \
    "\"$HUD\" detail --wait"
fi

tmux run-shell -b "$CURRENT_DIR/scripts/poll"

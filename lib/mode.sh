#!/usr/bin/env bash
# cupertino-xfce-mode: switch the whole look between light and dark.
#
#   cupertino-xfce-mode light | dark | toggle | status | monitors
#
# Installed by install.sh to ~/.local/share/cupertino-xfce/app and linked as
# ~/.local/bin/cupertino-xfce-mode. Also used by Control Center's Appearance toggle.
set -Eeuo pipefail

APP_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$APP_DIR/lib/common.sh"
STATE="$CONF_DIR/state"
WALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/cupertino-xfce"
QT_INI="${XDG_CONFIG_HOME:-$HOME/.config}/qterminal.org/qterminal.ini"
NOTIFY_THEME_DIR="$HOME/.themes"

# ---- per-mode look --------------------------------------------------------------------
mode_vars() {
  if [[ $1 == light ]]; then
    GTK_THEME="WhiteSur-Light"; ICON_THEME="WhiteSur-light"; WALLPAPER="blue-waves"
    BAR_RGBA=(0.97 0.97 0.98 0.62); BAR_FG="#1d1d1f"
    DOCK_BG="rgba(250, 250, 252, 0.42)"; DOCK_TOP="rgba(255, 255, 255, 0.45)"
    DOCK_BOTTOM="rgba(240, 240, 245, 0.38)"; DOCK_BORDER="rgba(255, 255, 255, 0.45)"
    DOT_COLOR="rgba(40,40,45,0.85)"
    SP_BG="rgba(246, 246, 248, 86%)"; SP_FG="#1d1d1f"; SP_FGDIM="rgba(29, 29, 31, 45%)"
    SP_BORDER="rgba(0, 0, 0, 12%)"; SP_LINE="rgba(0, 0, 0, 10%)"
    NOTIFY_BG="rgba(246, 246, 248, 0.82)"; NOTIFY_FG="#1d1d1f"; NOTIFY_BODY="rgba(29, 29, 31, 0.78)"
    NOTIFY_BORDER="rgba(0, 0, 0, 0.10)"; NOTIFY_HOVER="rgba(252, 252, 253, 0.92)"
    TERM_SCHEME="Cupertino-Light"; PLANK_THEME="Cupertino-Light"
  else
    GTK_THEME="WhiteSur-Dark"; ICON_THEME="WhiteSur"; WALLPAPER="dusk-waves"
    BAR_RGBA=(0.08 0.08 0.10 0.55); BAR_FG="#f5f5f7"
    DOCK_BG="rgba(44, 44, 54, 0.78)"; DOCK_TOP="rgba(52, 52, 62, 0.80)"
    DOCK_BOTTOM="rgba(36, 36, 44, 0.80)"; DOCK_BORDER="rgba(255, 255, 255, 0.16)"
    DOT_COLOR="rgba(255,255,255,0.85)"
    SP_BG="rgba(36, 36, 44, 88%)"; SP_FG="#f2f2f7"; SP_FGDIM="rgba(242, 242, 247, 55%)"
    SP_BORDER="rgba(255, 255, 255, 14%)"; SP_LINE="rgba(255, 255, 255, 10%)"
    NOTIFY_BG="rgba(40, 40, 46, 0.82)"; NOTIFY_FG="#f5f5f7"; NOTIFY_BODY="rgba(245, 245, 247, 0.78)"
    NOTIFY_BORDER="rgba(255, 255, 255, 0.12)"; NOTIFY_HOVER="rgba(52, 52, 60, 0.92)"
    TERM_SCHEME="Cupertino-Dark"; PLANK_THEME="Cupertino-Dark"
  fi
}

state_get() { [[ -f $STATE ]] && sed -n "s/^$1=//p" "$STATE" | tail -n 1; }
state_set() {
  mkdir -p "$(dirname "$STATE")"; touch "$STATE"
  sed -i "/^$1=/d" "$STATE"; printf '%s=%s\n' "$1" "$2" >> "$STATE"
}

render() { # template -> output, substituting {{VARS}}
  sed -e "s|{{ICON_THEME}}|$ICON_THEME|g" -e "s|{{SP_BG}}|$SP_BG|g" -e "s|{{SP_FG}}|$SP_FG|g" \
      -e "s|{{SP_FGDIM}}|$SP_FGDIM|g" -e "s|{{SP_BORDER}}|$SP_BORDER|g" -e "s|{{SP_LINE}}|$SP_LINE|g" \
      -e "s|{{NOTIFY_BG}}|$NOTIFY_BG|g" -e "s|{{NOTIFY_FG}}|$NOTIFY_FG|g" -e "s|{{NOTIFY_BODY}}|$NOTIFY_BODY|g" \
      -e "s|{{NOTIFY_BORDER}}|$NOTIFY_BORDER|g" -e "s|{{NOTIFY_HOVER}}|$NOTIFY_HOVER|g" "$1" > "$2"
}

sel() { local fmt=$1; shift; local out="" id; for id in "$@"; do out+="${out:+, }${fmt//ID/$id}"; done; printf '%s' "$out"; }

write_gtk_css() {
  local -a appmenu clock
  read -r -a appmenu <<<"$(state_get APPMENU_IDS)"
  read -r -a clock <<<"$(state_get CLOCK_IDS)"
  mkdir -p "$(dirname "$GTK_CSS")"; touch "$GTK_CSS"
  strip_block "$GTK_CSS"
  {
    echo "/* >>> cupertino-xfce >>> (managed by cupertino-xfce; edits inside this block are overwritten) */"
    echo "@define-color placeholder_text_color #8e8e93;"
    cat <<EOF
#docklike-10 > * {
  background-color: $DOCK_BG;
  background-image: linear-gradient($DOCK_TOP, $DOCK_BOTTOM);
  border: 1px solid $DOCK_BORDER;
  border-radius: 18px;
  padding: 0 8px;
  margin: 2px 0 4px 0;
}
EOF
    if [[ ${#appmenu[@]} -gt 0 ]]; then
      echo "$(sel '#appmenu-ID, #appmenu-ID *, #appmenu-ID menubar > menuitem label' "${appmenu[@]}") { color: $BAR_FG; }"
      echo "$(sel '#appmenu-ID menubar' "${appmenu[@]}") { background: transparent; box-shadow: none; border: none; }"
      echo "$(sel '#appmenu-ID menubar > menuitem' "${appmenu[@]}") { padding: 0 9px; }"
    fi
    [[ ${#clock[@]} -gt 0 ]] && echo "$(sel '#clock-ID, #clock-ID *' "${clock[@]}") { color: $BAR_FG; }"
    # status icons and the Control Center icon are symbolic: they take the bar's text colour
    echo "#XfcePanelWindow, $(sel '#ID, #ID *' systray-4 pulseaudio-5 power-manager-plugin-7 launcher-11 launcher-12) { color: $BAR_FG; }"
    cat "$APP_DIR/config/lockscreen.css"
    echo "/* <<< cupertino-xfce <<< */"
  } >> "$GTK_CSS"
}

# Connected outputs, the primary (or else the first) one first: it gets the full menu bar.
connected_outputs() {
  xrandr --listmonitors 2>/dev/null | awk 'NR > 1 { name = $2; prim = (name ~ /\*/); gsub(/^[+*]+/, "", name); print (prim ? 0 : 1), name }' \
    | sort -s -n -k1,1 | cut -d' ' -f2
}

# Wallpaper. Only ever replaces our own wallpapers (or, during install, everything), so a
# picture the user picked in Desktop Settings survives light/dark switches, logins and
# monitor changes. Monitors without an entry get the main monitor's picture.
set_wallpaper() {
  local wp="$WALL_DIR/$WALLPAPER.jpg" k v o w n base ref main
  [[ -f $wp ]] || return 0
  while IFS= read -r k; do
    v=$(xfconf-query -c xfce4-desktop -p "$k" 2>/dev/null || true)
    if [[ ${WALLPAPER_ALL:-0} == 1 || -z $v || $v == "$WALL_DIR/"* ]]; then
      xset_prop xfce4-desktop "$k" string "$wp"
    fi
  done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/workspace[0-9]+/last-image$' || true)
  main=$(connected_outputs | head -n 1)
  ref=$(xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor$main/workspace0/last-image" 2>/dev/null || true)
  [[ -n $ref ]] || ref=$wp
  n=$(xfconf-query -c xfwm4 -p /general/workspace_count 2>/dev/null || echo 4)
  while IFS= read -r o; do
    [[ -n $o ]] || continue
    for ((w = 0; w < n; w++)); do
      base="/backdrop/screen0/monitor$o/workspace$w"
      xfconf-query -c xfce4-desktop -p "$base/last-image" >/dev/null 2>&1 && continue
      xfconf-query -c xfce4-desktop -p "$base/last-image" -n -t string -s "$ref"
      xfconf-query -c xfce4-desktop -p "$base/image-style" >/dev/null 2>&1 \
        || xfconf-query -c xfce4-desktop -p "$base/image-style" -n -t int -s 5
    done
  done < <(connected_outputs)
}

set_dock_dots() {
  local rc="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/panel/docklike-10.rc"
  [[ -f $rc ]] || return 0
  sed -i -e "s|^indicatorColor=.*|indicatorColor=$DOT_COLOR|" -e "s|^inactiveColor=.*|inactiveColor=$DOT_COLOR|" "$rc"
}

set_plank_theme() {
  [[ $(state_get DOCK) == plank ]] || return 0
  gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ theme "$PLANK_THEME" 2>/dev/null || true
}

set_bar_colours() {
  local -a bars; local p
  read -r -a bars <<<"$(state_get BAR_PANELS)"
  for p in "${bars[@]}"; do
    xfconf-query -c xfce4-panel -p "/panels/panel-$p/background-rgba" -s "${BAR_RGBA[0]}" -s "${BAR_RGBA[1]}" -s "${BAR_RGBA[2]}" -s "${BAR_RGBA[3]}" 2>/dev/null || true
  done
}

# ---- one menu bar per connected monitor ------------------------------------------------
xp_new() { # channel-less helper for xfce4-panel: prop type value
  xfconf-query -c xfce4-panel -p "$1" -r -R 2>/dev/null || true
  xfconf-query -c xfce4-panel -p "$1" -n -t "$2" -s "$3"
}

new_bar() { # output -> creates a menu bar panel on it, prints the panel id
  local out=$1 p m app sep clk
  p=$(( $(xfconf-query -c xfce4-panel -p /panels 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -n 1) + 1 ))
  m=$(( $(xfconf-query -c xfce4-panel -l | sed -n 's|^/plugins/plugin-\([0-9]*\)$|\1|p' | sort -n | tail -n 1) + 1 ))
  app=$((m + 1)); sep=$((m + 2)); clk=$((m + 3))
  xp_new "/plugins/plugin-$m" string whiskermenu
  if [[ -n $(state_get APPMENU_IDS) ]]; then
    xp_new "/plugins/plugin-$app" string appmenu
    xp_new "/plugins/plugin-$app/bold-application-name" bool false
    xp_new "/plugins/plugin-$app/plugins/plugin-$app/expand" bool true
  else
    xp_new "/plugins/plugin-$app" string separator
  fi
  xp_new "/plugins/plugin-$sep" string separator
  xp_new "/plugins/plugin-$sep/expand" bool true
  xp_new "/plugins/plugin-$sep/style" uint 0
  xp_new "/plugins/plugin-$clk" string clock
  xp_new "/plugins/plugin-$clk/digital-layout" uint 3
  xp_new "/plugins/plugin-$clk/digital-time-font" string "Inter Semi-Bold 10"
  xp_new "/plugins/plugin-$clk/digital-time-format" string "%a %b %-d  %-I:%M %p"
  xp_new "/plugins/plugin-$clk/mode" uint 2
  xfconf-query -c xfce4-panel -p "/panels/panel-$p/background-rgba" -n -a \
    -t double -s "${BAR_RGBA[0]}" -t double -s "${BAR_RGBA[1]}" -t double -s "${BAR_RGBA[2]}" -t double -s "${BAR_RGBA[3]}"
  xp_new "/panels/panel-$p/background-style" uint 1
  xp_new "/panels/panel-$p/length" uint 100
  xp_new "/panels/panel-$p/output-name" string "$out"
  xp_new "/panels/panel-$p/position" string "p=6;x=0;y=0"
  xp_new "/panels/panel-$p/position-locked" bool true
  xp_new "/panels/panel-$p/size" uint 28
  xfconf-query -c xfce4-panel -p "/panels/panel-$p/plugin-ids" -n -a \
    -t int -s "$m" -t int -s "$app" -t int -s "$sep" -t int -s "$clk"
  local -a ids=(); local id
  mapfile -t ids < <(xfconf-query -c xfce4-panel -p /panels | grep -E '^[0-9]+$')
  ids+=("$p")
  local -a args=(); for id in "${ids[@]}"; do args+=(-t int -s "$id"); done
  xfconf-query -c xfce4-panel -p /panels -a "${args[@]}"
  [[ -n $(state_get APPMENU_IDS) ]] && state_set APPMENU_IDS "$(state_get APPMENU_IDS) $app"
  state_set CLOCK_IDS "$(state_get CLOCK_IDS) $clk"
  state_set BAR_PANELS "$(state_get BAR_PANELS) $p"
}

# Give every connected monitor exactly one menu bar: keep bars whose monitor is still
# there, move bars whose monitor is gone, and only create a bar when there are more
# monitors than bars. Prints "restart" when the panel needs restarting.
sync_bars() {
  local -a outs bars free=(); local p o
  declare -A used=()
  mapfile -t outs < <(connected_outputs)
  [[ ${#outs[@]} -gt 0 ]] || return 0
  read -r -a bars <<<"$(state_get BAR_PANELS)"
  [[ ${#bars[@]} -gt 0 ]] || return 0
  # The first bar (with the status icons) belongs on the main monitor.
  xset_prop xfce4-panel "/panels/panel-${bars[0]}/output-name" string "${outs[0]}"
  used[${outs[0]}]=${bars[0]}
  for p in "${bars[@]:1}"; do
    o=$(xfconf-query -c xfce4-panel -p "/panels/panel-$p/output-name" 2>/dev/null || true)
    if [[ -n $o && -z ${used[$o]:-} ]] && printf '%s\n' "${outs[@]}" | grep -qxF -- "$o"; then
      used[$o]=$p
    else
      free+=("$p")
    fi
  done
  local restart=0
  for o in "${outs[@]}"; do
    [[ -n ${used[$o]:-} ]] && continue
    if [[ ${#free[@]} -gt 0 ]]; then
      p=${free[0]}; free=("${free[@]:1}")
      xset_prop xfce4-panel "/panels/panel-$p/output-name" string "$o"
    else
      new_bar "$o"; restart=1
    fi
    used[$o]=1
  done
  # Spare bars wait (hidden) for their monitor; park any that would duplicate a bar.
  for p in "${free[@]}"; do
    o=$(xfconf-query -c xfce4-panel -p "/panels/panel-$p/output-name" 2>/dev/null || true)
    if [[ -z $o ]] || printf '%s\n' "${outs[@]}" | grep -qxF -- "$o"; then
      xset_prop xfce4-panel "/panels/panel-$p/output-name" string "cupertino-spare-$p"
    fi
  done
  [[ $restart == 1 ]] && echo restart
  return 0
}

sync_monitors() {
  local cur; cur=$(state_get MODE || true)
  mode_vars "${cur:-light}"
  set_wallpaper
  if [[ $(sync_bars) == restart ]]; then
    write_gtk_css
    xfce4-panel -r >/dev/null 2>&1 || true
  fi
}

set_notify_theme() {
  local d="$NOTIFY_THEME_DIR/Cupertino-Notify/xfce-notify-4.0"
  mkdir -p "$d"
  render "$APP_DIR/config/notify.css.in" "$d/gtk.css"
  xset_prop xfce4-notifyd /theme string Cupertino-Notify
  # xfce4-notifyd caches the theme CSS; it restarts on the next notification.
  pkill -u "$(id -u)" -x xfce4-notifyd 2>/dev/null || true
}

set_terminal() {
  [[ -f $QT_INI && -f $CONF_DIR/qterminal.keys ]] || return 0
  python3 "$APP_DIR/lib/ini-set.py" "$QT_INI" General colorScheme "$TERM_SCHEME" >/dev/null
  local sec key val
  while IFS=$'\t' read -r sec key val; do
    [[ -n $sec ]] && python3 "$APP_DIR/lib/ini-set.py" "$QT_INI" "$sec" "$key" "$val" >/dev/null
  done < "$CONF_DIR/qterminal.keys"
}

apply_mode() {
  local mode=$1
  mode_vars "$mode"
  xset_prop xsettings /Net/ThemeName string "$GTK_THEME"
  xset_prop xsettings /Net/IconThemeName string "$ICON_THEME"
  xset_prop xfwm4 /general/theme string "$GTK_THEME"
  mkdir -p "$CONF_DIR/rofi"
  render "$APP_DIR/config/rofi/spotlight.rasi.in" "$CONF_DIR/rofi/spotlight.rasi"
  render "$APP_DIR/config/rofi/launchpad.rasi.in" "$CONF_DIR/rofi/launchpad.rasi"
  render "$APP_DIR/config/rofi/missioncontrol.rasi.in" "$CONF_DIR/rofi/missioncontrol.rasi"
  write_gtk_css
  set_notify_theme
  set_terminal
  set_wallpaper
  set_bar_colours
  set_dock_dots
  set_plank_theme
  state_set MODE "$mode"
  # The dock re-reads its dot colours and the bars their CSS on restart.
  if [[ ${NO_PANEL_RESTART:-0} != 1 ]]; then
    xfce4-panel -r >/dev/null 2>&1 || true
  fi
}

main() {
  local cmd=${1:-status} cur
  cur=$(state_get MODE); cur=${cur:-light}
  case $cmd in
    light|dark) apply_mode "$cmd" ;;
    toggle) apply_mode "$([[ $cur == light ]] && echo dark || echo light)" ;;
    status) echo "$cur" ;;
    once) # run once at the first login after install: re-apply terminal settings that an
          # open QTerminal overwrote when it closed, then remove this autostart entry
      mode_vars "$cur"; set_terminal
      rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/cupertino-xfce-once.desktop" ;;
    monitors) # a monitor was plugged in or out: wallpaper and a menu bar on every screen
      sync_monitors ;;
    *) echo "usage: cupertino-xfce-mode light|dark|toggle|status|monitors" >&2; exit 2 ;;
  esac
}

# Run main only when executed, not when sourced by install.sh.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi

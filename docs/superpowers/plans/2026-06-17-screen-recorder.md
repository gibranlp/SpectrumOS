# SpectrumOS Screen Recorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Rofi-based screen recording utility for SpectrumOS using `wf-recorder`.

**Architecture:** A shell script `SOS_Recorder.sh` manages `wf-recorder` processes and uses Rofi for user interaction. A custom Rofi theme `SOS_Recorder.rasi` provides a left-side UI.

**Tech Stack:** Bash, Rofi, `wf-recorder`, `hyprctl`, `slurp`, `notify-send`.

---

### Task 1: Create Rofi Theme

**Files:**
- Create: `config/rofi/SOS_Recorder.rasi`

- [ ] **Step 1: Create the Rofi theme file**

Create `config/rofi/SOS_Recorder.rasi` by adapting `config/rofi/SOS_Left.rasi`.

```css
/*****----- Global Properties -----*****/
@import "~/.cache/wal/SOS_Colors.rasi" 

/*****----- Main Window -----*****/
window {
    location:                    northwest;
    margin:                      5px;
    fullscreen:                  false;
    width:                       25%;
    height:                      100%;
    border-radius:               2px;
    enabled:                     true;
    cursor:                      "default";
    background-color:            @background;
    padding:                     4px;
}

/*****----- Main Box -----*****/
mainbox {
    enabled:                     true;
    spacing:                     0px;
    background-color:            transparent;
    orientation:                 vertical;
    children:                    [ "inputbar", "listview" ];
}

/*****----- Inputbar -----*****/
inputbar {
    enabled:                     true;
    spacing:                     10px;
    padding:                     100px 20px;
    background-color:            transparent;
    background-image:            url("/var/lib/spectrumos/current.png", width);
    text-color:                  @background;
    orientation:                 horizontal;
    children:                    ["prompt"];
    border-radius:               0px;
}

prompt {
    padding:                     12px 16px;    
    border-radius:               2px;
    background-color:            @background;
    text-color:                  @color1;
    horizontal-align:            0.5;
}

/*****----- Listview -----*****/
listview {
    enabled:                     true;
    columns:                     1;
    lines:                       8;
    cycle:                       true;
    dynamic:                     true;
    scrollbar:                   false;
    layout:                      vertical;
    reverse:                     false;
    fixed-height:                true;
    fixed-columns:               true;
    spacing:                     10px;
    padding:                     10px;
    background-color:            transparent;
    text-color:                  @foreground;
    cursor:                      "default";
}

/*****----- Elements -----*****/
element {
    enabled:                     true;
    spacing:                     10px;
    padding:                     12px;
    border-radius:               2px;
    background-color:            transparent;
    text-color:                  @foreground;
    cursor:                      pointer;
}
element normal.normal {
    background-color:            inherit;
    text-color:                  inherit;
}
element selected.normal {
    background-color:            @color3;
    text-color:                  @background;
}
element-text {
    background-color:            transparent;
    text-color:                  inherit;
    cursor:                      inherit;
    vertical-align:              0.5;
    horizontal-align:            0;
}
```

- [ ] **Step 2: Commit**

```bash
git add config/rofi/SOS_Recorder.rasi
git commit -m "style: add Rofi theme for screen recorder"
```

---

### Task 2: Create Main Recorder Script

**Files:**
- Create: `bin/SOS_Recorder.sh`

- [ ] **Step 1: Write the script logic**

Create `bin/SOS_Recorder.sh` with the following content:

```bash
#!/usr/bin/env bash
# SpectrumOS Screen Recorder

ROFI_THEME="$HOME/.config/rofi/SOS_Recorder.rasi"
FONT="Courier Prime Medium 13"
VIDEO_DIR="$HOME/Videos"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$VIDEO_DIR"

# Check if recording is active
if pgrep -x "wf-recorder" > /dev/null; then
    CHOICE=$(echo -e "🛑 Stop Recording" | rofi -dmenu -theme "$ROFI_THEME" -p " Recorder Active " -font "$FONT" -lines 1)
    if [ "$CHOICE" == "🛑 Stop Recording" ]; then
        pkill -SIGINT wf-recorder
        notify-send -a 'Recorder' "Recording stopped and saved to $VIDEO_DIR"
    fi
    exit 0
fi

# Main Menu
OPTIONS="🖥️ Record Monitor\n📐 Record Area"
ACTION=$(echo -e "$OPTIONS" | rofi -dmenu -theme "$ROFI_THEME" -p " Screen Recorder " -font "$FONT" -lines 2)

case "$ACTION" in
    "🖥️ Record Monitor")
        # Get monitors
        MONITORS=$(hyprctl monitors -j | jq -r '.[] | .name')
        MONITOR_CHOICE=$(echo -e "$MONITORS" | rofi -dmenu -theme "$ROFI_THEME" -p " Select Monitor " -font "$FONT")
        
        if [ -n "$MONITOR_CHOICE" ]; then
            notify-send -a 'Recorder' "Starting recording on $MONITOR_CHOICE..."
            wf-recorder -a -o "$MONITOR_CHOICE" -f "$VIDEO_DIR/recording_$TIMESTAMP.mp4" &
        fi
        ;;
        
    "📐 Record Area")
        GEOM=$(slurp)
        if [ -n "$GEOM" ]; then
            notify-send -a 'Recorder' "Starting area recording..."
            wf-recorder -a -g "$GEOM" -f "$VIDEO_DIR/recording_$TIMESTAMP.mp4" &
        fi
        ;;
esac
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x bin/SOS_Recorder.sh`

- [ ] **Step 3: Commit**

```bash
git add bin/SOS_Recorder.sh
git commit -m "feat: add SOS_Recorder.sh script"
```

---

### Task 3: Verification

- [ ] **Step 1: Test monitor recording**

1. Run `./bin/SOS_Recorder.sh`.
2. Select "🖥️ Record Monitor".
3. Select a monitor.
4. Verify notification appears.
5. Wait a few seconds.
6. Run `./bin/SOS_Recorder.sh` again.
7. Select "🛑 Stop Recording".
8. Verify file exists in `~/Videos` and plays with audio.

- [ ] **Step 2: Test area recording**

1. Run `./bin/SOS_Recorder.sh`.
2. Select "📐 Record Area".
3. Select an area with mouse.
4. Verify notification appears.
5. Wait a few seconds.
6. Run `./bin/SOS_Recorder.sh` again.
7. Select "🛑 Stop Recording".
8. Verify file exists in `~/Videos` and plays with audio.

# SpectrumOS Screen Recorder Design Spec

## Overview
A Rofi-based screen recording utility for SpectrumOS using `wf-recorder`. It provides a simple interface to record specific monitors or a selected area with audio.

## Components

### 1. `bin/SOS_Recorder.sh` (Shell Script)
- **Logic**:
    - Check if `wf-recorder` is already running.
    - If running, primary menu option is "🛑 Stop Recording".
    - If not running, primary menu options are:
        - "🖥️ Record Monitor"
        - "📐 Record Area"
    - **Stop Logic**: `pkill -SIGINT wf-recorder` (SIGINT ensures the file is finalized correctly).
    - **Monitor Selection**: Uses `hyprctl monitors -j` to list available outputs.
    - **Area Selection**: Uses `slurp` to get coordinates for `wf-recorder -g`.
    - **Command**: `wf-recorder -a -o <output> -f ~/Videos/recording_<timestamp>.mp4`
    - **Notifications**: `notify-send` for start/stop/save events.

### 2. `config/rofi/SOS_Recorder.rasi` (Rofi Theme)
- Based on `SOS_Left.rasi`.
- Positioned `northwest` (left side).
- Visuals consistent with SpectrumOS theme (Pywal colors).

## Data Flow
1. User triggers `SOS_Recorder.sh`.
2. Script checks for active `wf-recorder` process.
3. Rofi displays the "Action" menu.
4. User selects an action.
5. If "Record Monitor", Rofi displays a list of monitors.
6. `wf-recorder` starts in the background.
7. User triggers `SOS_Recorder.sh` again to stop.
8. Recording is saved to `~/Videos`.

## Success Criteria
- [ ] Rofi menu appears on the left side.
- [ ] Can record a specific monitor with audio.
- [ ] Can record a selected area with audio.
- [ ] Can stop an active recording via the same Rofi menu.
- [ ] Files are saved with correct timestamps in `~/Videos`.
- [ ] Notifications show recording status.

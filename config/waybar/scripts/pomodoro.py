#!/usr/bin/env python3
import os
import sys
import time
import json
import subprocess
from pathlib import Path

# Constants
CACHE_DIR = Path.home() / ".cache" / "spectrumos"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

STATE_FILE = CACHE_DIR / "pomodoro_state.json"
TASKS_FILE = CACHE_DIR / "tasks.txt"
if not TASKS_FILE.exists():
    TASKS_FILE.touch()

WORK_TIME = 25 * 60
BREAK_TIME = 5 * 60

def get_state():
    if not STATE_FILE.exists():
        return {"state": "INACTIVE", "remaining": WORK_TIME, "current_task": "", "last_tick": 0}
    with open(STATE_FILE, "r") as f:
        return json.load(f)

def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

def notify(title, message):
    subprocess.run(["notify-send", "-a", "󱎫 Pomodoro", title, message])

def update_timer():
    state = get_state()
    if state["state"] == "RUNNING" or state["state"] == "BREAK":
        now = int(time.time())
        elapsed = now - state["last_tick"]
        if elapsed >= 1:
            state["remaining"] -= elapsed
            state["last_tick"] = now
            
            if state["remaining"] <= 0:
                if state["state"] == "RUNNING":
                    notify("Work session finished!", "Time for a 5 minute break.")
                    state["state"] = "BREAK"
                    state["remaining"] = BREAK_TIME
                else:
                    notify("Break finished!", "Ready to get back to work?")
                    state["state"] = "INACTIVE"
                    state["remaining"] = WORK_TIME
            save_state(state)
    return state

def format_time(seconds):
    minutes = seconds // 60
    seconds = seconds % 60
    return f"{minutes:02d}:{seconds:02d}"

def get_tasks():
    with open(TASKS_FILE, "r") as f:
        return [line.strip() for line in f if line.strip()]

def save_tasks(tasks):
    with open(TASKS_FILE, "w") as f:
        for task in tasks:
            f.write(f"{task}\n")

def manage_tasks():
    tasks = get_tasks()
    state = get_state()
    
    options = ["󰐕 Add Task"]
    if state["current_task"]:
        options.append(f"󰄬 Complete: {state['current_task']}")
    
    if tasks:
        options.append("--- Select Task ---")
        options.extend(tasks)
    
    rofi_input = "\n".join(options)
    res = subprocess.run(
        ["rofi", "-dmenu", "-p", "󰚥 Tasks", "-i", "-theme", f"{Path.home()}/.config/rofi/SOS_Left.rasi"],
        input=rofi_input, text=True, capture_output=True
    ).stdout.strip()
    
    if not res:
        return

    if res == "󰐕 Add Task":
        while True:
            new_task = subprocess.run(
                ["rofi", "-dmenu", "-p", "New Task (Empty to Finish)", "-theme", f"{Path.home()}/.config/rofi/SOS_Left.rasi"],
                text=True, capture_output=True
            ).stdout.strip()
            if new_task:
                tasks.append(new_task)
                save_tasks(tasks)
                if not state["current_task"]:
                    state["current_task"] = new_task
                    save_state(state)
                notify("Task Added", new_task)
            else:
                break
        manage_tasks() # Return to main menu after adding tasks
    elif res.startswith("󰄬 Complete:"):
        if state["current_task"] in tasks:
            tasks.remove(state["current_task"])
            save_tasks(tasks)
        state["current_task"] = tasks[0] if tasks else ""
        save_state(state)
        notify("Task Completed!", "Great job!")
    elif res in tasks:
        state["current_task"] = res
        save_state(state)

def toggle_timer():
    state = get_state()
    if state["state"] == "INACTIVE":
        state["state"] = "RUNNING"
        state["last_tick"] = int(time.time())
        notify("Pomodoro Started", f"Focusing on: {state['current_task'] or 'No task'}")
    elif state["state"] == "RUNNING":
        state["state"] = "PAUSED"
    elif state["state"] == "PAUSED":
        state["state"] = "RUNNING"
        state["last_tick"] = int(time.time())
    elif state["state"] == "BREAK":
        state["state"] = "BREAK_PAUSED" # Break can also be paused
    elif state["state"] == "BREAK_PAUSED":
        state["state"] = "BREAK"
        state["last_tick"] = int(time.time())
    save_state(state)

def output_waybar():
    state = update_timer()
    status = state["state"]
    remaining = format_time(state["remaining"])
    task = state["current_task"] or "No Active Task"
    
    icon = "󱎫"
    if status == "RUNNING":
        icon = "󰔟"
    elif status == "BREAK":
        icon = "󰓛"
    elif status == "PAUSED" or status == "BREAK_PAUSED":
        icon = "󰏤"
        
    text = f"{icon} {remaining} | {task}"
    
    print(json.dumps({
        "text": text,
        "tooltip": f"State: {status}\nTask: {task}\nClick: Toggle Timer\nRight Click: Manage Tasks",
        "class": status.lower()
    }))

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "toggle":
            toggle_timer()
        elif cmd == "tasks":
            manage_tasks()
        elif cmd == "reset":
            save_state({"state": "INACTIVE", "remaining": WORK_TIME, "current_task": "", "last_tick": 0})
    else:
        output_waybar()

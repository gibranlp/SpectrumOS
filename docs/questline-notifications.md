# Questline desktop notifications

Requires Questline 2.0.2 or later. Finishing tasks, sidequests and steps in the widget reports the XP actually recorded by Questline, including its native bonuses. New levels and newly unlocked achievements also produce desktop alerts. Editing and repeated completion attempts do not replay old rewards. Routine autosave stays quiet unless it unlocks a level or achievement.

`spectrum-questline-notifications.service` runs `questline desktop-notifications` during the graphical session. It keeps native Swarm and hydration reminders running when the terminal app and widget are closed. The Swarm uses local cached chapter progress, its existing cooldowns and five-message session limit. It stops when the cached chapter is complete. No chapter refresh or chapter reward is performed by this notifier.

Hydration follows the existing Questline settings: enabled state, reminder interval, active hours, and pause during focus. Configure these in Questline's hydration settings. A reminder shows your current daily count and target, such as `3/12 today`. It stays visible until **Ctrl + Space** dismisses it or you click **Drink**. Drink records one glass through Questline’s native hydration logic, including daily target XP and achievements. Repeated clicks or stale reminder tokens cannot count the same reminder twice. Dismissal records no drink. The next reminder waits for the configured interval after dismissal or drinking, and no new reminder is issued after the daily target is reached. SpectrumOS focus sessions suppress Swarm interruptions and pause hydration when that preference is enabled.

Swarm cards always use Questline’s purple palette; hydration cards always use blue, independent of the wallpaper palette. Both the popup and notification history expose the Drink button for active water reminders.

Questline's external-notification toggle controls both reward alerts and background reminders. Notifications use normal urgency and the standard desktop notification service, so the desktop's Do Not Disturb policy still applies. While the full terminal app is open, a presence lock pauses background reminders and lets the app handle its own reminders. The background service runs once per storage profile and starts without replaying past rewards.

Inspect or restart the service with:

```sh
systemctl --user status spectrum-questline-notifications.service
systemctl --user restart spectrum-questline-notifications.service
```

Questline reads its existing database and settings under its usual storage directory, including `QUESTLINE_STORAGE_DIR` overrides. Reminder coordination files `desktop-tui.lock` and `desktop-notifications.lock` live in that directory; they contain no task data or identity keys.

The private `questline.hydration.json` coordination file keeps the current reminder token, daily progress snapshot and acknowledgment time. The database remains authoritative for drinks and rewards. Its matching `.hydration.lock` serializes drink and dismissal actions. Neither file belongs in the repository or an ISO. The reminder service follows the shell lifecycle and restores pending reminders when the desktop notification server restarts.

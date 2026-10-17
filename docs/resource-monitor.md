# Resource warnings

SpectrumOS runs `/usr/lib/spectrumos/resource-monitor` as a lightweight user service during the graphical session. It samples kernel counters every five seconds and sends replaceable Dunst notifications for:

- available memory at or below 15%, escalating to critical at 8%;
- zram or other swap at or above 85% while available memory is below 25%, with critical escalation when memory falls below 15% and swap reaches 97%;
- aggregate CPU use at or above 95% for at least 60 seconds; and
- root filesystem space at or below 10% or 10 GiB, escalating at 5% or 2 GiB.

Memory notifications include the three largest resident process groups so the user can act before the kernel OOM killer intervenes. Warning notifications repeat no more than every 15 minutes and critical notifications no more than every five minutes; escalation is immediate. CPU warnings reset after utilization falls to 80%.

Run `resource-monitor --once` for a manual memory and disk check. CPU saturation requires continuous sampling and is therefore detected only while the service is running.

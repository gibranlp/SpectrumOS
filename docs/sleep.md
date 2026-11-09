# Sleep and wake reliability

SpectrumOS retains the kernel/firmware suspend variant by default. It does not
force S3, disable wake controllers globally, unload graphics drivers, restart
network/audio services after every wake, or enable unvalidated hibernation.
Sleep support is model-, firmware-, kernel-, and driver-specific.

## Inspect a machine

Run `spectrum-sleep doctor` in the desktop session. For the complete report:

```sh
spectrum-sleep doctor --json > sleep-report.json
sudo spectrum-sleep doctor --json > sleep-report-root.json
```

The report includes exposed sleep states, selected variant, firmware version,
batteries, kernel counters, wake devices, inhibitors, graphics drivers, effective
sleep/lid configuration, login1 hibernation capability, and bounded journal output.
NVIDIA inspection includes loaded parameters, service enablement, VRAM totals,
backing filesystem and available space. Missing access or commands are recorded
as errors, not successful checks. Reports are local; review device, process and
journal details before sharing. No diagnostics command requests sleep.

Hypridle explicitly uses `inhibit_sleep = 3`, waiting for the lock notification
before releasing its delay inhibitor. Logind's inhibitor timeout still applies;
verify a visible locked screen and the active Hypridle inhibitor on each machine.
Existing display-on commands run after resume. Physical lock/display acceptance
is required; a configured command does not establish that locking succeeded.

## Retain evidence automatically

Package-owned drop-ins add short, best-effort pre/post collectors to systemd's
suspend, hibernate, hybrid-sleep and suspend-then-hibernate services. There is no
background polling daemon and no change to their main sleep command. The collector
reads sysfs/procfs without launching subprocesses or contacting the desktop bus.
Each collector has a five-second deadline. Recording failures do not block sleep. `ExecStopPost` also captures failed attempts.

Records are private to root in `/var/lib/spectrumos/sleep` (directory 0700, files
0600): `pre.json`, `post.json`, and up to 40 timestamped records. They include boot
and invocation identifiers, service result, counters, battery values and wake IRQ.
An interrupted pre record survives reboot; a missing matching post record is
incomplete evidence, not proof of a specific failure. Combined sleep operations
may contain multiple transitions inside one service invocation.

```sh
sudo cat /var/lib/spectrumos/sleep/post.json
journalctl -b -u systemd-suspend.service
journalctl -b -1 -k
```

Comparison reports elapsed time and time suspended from BOOTTIME minus MONOTONIC,
plus counter and battery changes. Average watts cover the whole measured interval,
including its awake portions. They are not measured hardware sleep residency or
resume latency. Battery capacity percentage points have coarse resolution. AC
transitions and charging invalidate a battery-drain test. Hardware residency
counters appear in `stats` only when the kernel/platform exposes them.

## Choose a suspend variant

Only change this after inspecting and testing the specific machine:

```sh
sudo spectrum-sleep mode s2idle
sudo spectrum-sleep mode deep
sudo spectrum-sleep mode auto
systemd-analyze cat-config systemd/sleep.conf
```

Unsupported variants are rejected before writing. `auto` clears SpectrumOS's
MemorySleepMode override and leaves selection to kernel defaults or other admin
settings. These commands atomically write only
`/etc/systemd/sleep.conf.d/60-spectrumos-memory.conf`; they do not suspend, reboot,
change firmware or modify the boot command line. Later administrator overrides
can take precedence. Changes apply on the next sleep request. Listing only
`[s2idle]` does not establish that the platform reaches a low-power S0ix state.

## Physical acceptance procedure

Save work before requesting sleep. Use the session menu or `systemctl suspend`
when physically present. Do not run an unattended repeated-suspend loop on an
unvalidated machine. To compare a controlled interval:

```sh
spectrum-sleep snapshot > before.json
# Solicita la suspensión desde el menú de sesión y despierta el equipo físicamente.
spectrum-sleep snapshot > after.json
spectrum-sleep compare before.json after.json
```

Record model, firmware, kernel, GPU/module variant, driver version, sleep mode,
dock/displays, battery/AC state, package version and result for every run.

| Hardware group | Required coverage |
| --- | --- |
| Intel laptop with integrated graphics | Battery/AC, lid, Wi-Fi/BT, internal/external displays |
| AMD laptop with integrated graphics | Battery/AC, hardware sleep residency, lid and wake sources |
| Intel + NVIDIA and AMD + NVIDIA laptops | Both GPU paths, VRAM workloads, internal/external displays |
| AMD, Intel and NVIDIA desktops | Power-button/keyboard wake, USB devices, displays, network/audio |
| USB-C/Thunderbolt docks | Docked/undocked, external display, Ethernet, USB and lid behavior |

For each supported configuration, run 20 short cycles, a two-hour battery test,
and an overnight test. Check lock-before-sleep, authorized wake sources, unexpected
wakes, time to usable locked display, input, network, Bluetooth, audio and active
GPU applications after every wake. Record failures individually. Choose and record
battery drain and resume-time targets for the hardware class before acceptance;
do not claim universal pass thresholds from one desktop. Repeat after material
firmware, kernel, graphics-driver or compositor changes. VM tests do not establish
physical sleep support.

## NVIDIA and hibernation gates

The installer retains VRAM preservation and NVIDIA sleep services. Verify the
installed driver's documentation and effective loaded parameters: newer open
modules can use kernel suspend notifiers, while the proprietary preservation path
requires matching NVIDIA services. Do not enable a second mechanism blindly.
Check that backing storage supports unnamed temporary files and has at least total
VRAM plus 5% available; a small tmpfs can cause suspend failure. The diagnostic
report supplies evidence but does not automatically alter driver parameters.

Hibernation requires persistent swap with adequate space, a correct restore path
(including encryption and initramfs), and a successful physical restore test.
Zram alone cannot retain a hibernation image. A swap file on Btrfs needs its correct
resume offset and filesystem-specific preparation. `CanHibernate=yes` is a
capability signal, not restore acceptance. Enable suspend-then-hibernate only after
plain hibernation and its battery/timer wake path pass on that machine. The tool
does not repartition disks, create swap or advertise an untested restore path.

## Investigate failures

Separate failure to enter sleep, immediate wake, excessive drain, and successful
kernel resume with a broken display or peripheral. Use counters, the failed device
and step, the recorded wake IRQ, journal and driver evidence to identify the layer.
Test a current supported kernel and the distro's supported LTS kernel on the same
machine before introducing a workaround. Firmware and microcode updates should be
reviewed against the vendor's instructions. Add exceptions only with exact hardware
matching, evidence, a rollback path and a retest condition.

Upstream references:

- [Kernel sleep states](https://www.kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html)
- [Kernel suspend debugging](https://www.kernel.org/doc/html/latest/power/basic-pm-debugging.html)
- [AMD sleep debugging and residency](https://www.kernel.org/doc/html/latest/arch/x86/amd-debugging.html)
- [NVIDIA power management](https://download.nvidia.com/XFree86/Linux-x86_64/615.71.09/README/powermanagement.html)
- [Hypridle lock and sleep inhibition](https://wiki.hypr.land/hypr-ecosystem/user/hypridle/)

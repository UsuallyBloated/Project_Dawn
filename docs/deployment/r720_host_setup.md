# R720 Host Setup Runbook

Step-by-step build of the physical box that will host the Project Dawn server. This is
the first real deployment in the project's history; everything before this ran on
localhost. It covers the sequence from bare hardware through to a running, reachable
`projectdawn-server`.

Works like the playtest checklists in `docs/playtest_notes/`: tick rows in place as you
go and fill the `notes:` hooks, because those notes are what make a "didn't work" result
triage-able later. Unlike a playtest checklist, this one has **check-in gates** between
stages, since a wrong answer at several of these points means starting over.

Related: the **Hosting / deployment** item in the CLAUDE.md To-Do, and Phase 2 in
`docs/schedule.md`.

> ## Scope: this doc covers bare metal to a hardened Linux host
>
> **The server repo already has an application deployment guide**, written 2026-08-05 from
> source: `server/docs/deployment_linux.md`, with `scripts/projectdawn.service` and
> `scripts/backup.sh` alongside it. It is the authority for everything from installing the
> app onward, and it is better informed than this file was: it covers the NTP/ConnectToken
> clock requirement, the missing SIGTERM handler, WAL mode, and the operational gaps.
>
> **This runbook owns Stages A through H2** — RAID, OS install, network, SSH, baseline
> hardening. That is the ground `deployment_linux.md` assumes already exists.
>
> **From Stage I onward, follow `deployment_linux.md`.** The Stage I and J material below is
> kept because it records what was actually done on this machine and the gotchas hit along
> the way, but where the two disagree, the server-repo guide wins.
>
> This was discovered late, on 2026-08-08, after Stages I and J had been worked through
> independently. Two differences matter and are reconciled in "Layout correction" below.

**Started:** 2026-08-05
**Status:** in progress. **Stages A through G closed 2026-08-05.** Storage built and
verified, and Ubuntu Server 26.04 LTS installed and booting. The install ran **offline**,
so everything needing a package download is deferred.

**Stage H all but closed 2026-08-07.** The server lives in the basement, cabled to the
network. `eno1` came up on its own from the `dhcp4: true` staged in advance, DNS resolves,
the gateway pings at 0% loss, the deferred `apt full-upgrade` is done, and key-based SSH
from the dev box survives a cold reboot. The machine is now headless: monitor and keyboard
are no longer required.

**Stage H2 baseline hardening done 2026-08-07:** UFW default-deny inbound with only SSH
allowed, SSH password auth disabled and proven refused, root login off, unattended security
upgrades on with automatic reboot explicitly disabled. SSH is the only network-reachable
service on the box.

**One item still open in Stage H: the H6 DHCP reservation.** Router credentials are not to
hand yet. Until the address is pinned, a lease change will break SSH and, later, the Stage K
port forward. A host-key prompt reappearing for an address already in `known_hosts` is one
symptom of exactly that.

**Stage I done 2026-08-07** except the battery check (I6): toolchain installed and honouring
the 1.95.0 pin, repo cloned via a read-only GitHub deploy key, release build green in
2m 38s, and the binary proven to refuse startup without `PROJECTDAWN_NETCODE_KEY`.

**The server is live 2026-08-10.** Running under systemd as the `projectdawn` service
account from `/opt/projectdawn`, on the `fix/xp-leveling-overflow` branch so every Phase 1
exploit gate is present, reachable over Tailscale at `100.93.108.112`, with UFW scoped to
the `tailscale0` interface. Boot line confirms `dev_cmds=false` and a tailnet
`world_endpoint`.

**Self-smoke-test passed 2026-08-10.** From the dev box over the tailnet: registered an
account, created a character, killed something, logged out cleanly, logged back in and found
the character where it was left with its XP intact. Auth, world, combat, persistence and the
DB write path all exercised. GM granted to exactly one account and audited.

**This is BUILT, not DONE.** The To-Do defines done as *"someone who is not you, from a
machine that is not yours."* The above was a rehearsal from the operator's own machine.
Remaining before inviting anyone: backups (`deployment_linux.md` §8) and a refreshed
`README_FOR_TESTERS.md`.

**As installed:** hostname `projectdawn`, user `wrightt`, kernel `7.0.0-14-generic
x86_64`, root filesystem 544.92GB on `ubuntu-vg/ubuntu-lv`.

---

## The machine

| | |
|---|---|
| Model | Dell PowerEdge R720 |
| Service Tag | 6D8LBY1 |
| RAID controller | PERC H710P Mini |
| NICs | 4x Broadcom Gigabit BCM5720 (`B8:CA:3A:F7:35:92` through `:95`) |
| Optical | PLDS DVD-ROM DS-8D9SH |
| Drives | 5x 300GB 15K SAS (Seagate ST9300653SS, mfg 2013) + 3x 1.2TB SAS |
| Boot mode | UEFI |

### Starting condition

The box arrived failing to boot with `No boot device available` and a
`Boot Failed: Windows Boot Manager` line. Diagnosis: the drives were never assembled into
a virtual disk, so the BIOS had nothing bootable to find, and the `Windows Boot Manager`
entry was a stale UEFI NVRAM pointer left by the previous owner's install. The PERC
enumerated fine and disk 00:01:00 reported `Ready`, so no hardware fault. This is the
normal state of a wiped, resold PowerEdge.

### Target disk layout

**As built, verified 2026-08-05** via `Virtual Disk Management > View Disk Group
Properties` and `Physical Disk Management > View Global Hot Spares`:

| Volume | Disks | Level | Reported | Expected | Purpose |
|---|---|---|---|---|---|
| VD0 `os` (Disk Group #0) | 4x 300GB | RAID 10 (2 spans of 2) | **557GB**, Ready | 558.8 GiB | Ubuntu, `projectdawn-server`, `world.db` |
| VD1 `data` (Disk Group #2) | 3x 1.2TB | RAID 5 | **2234GB**, Ready | 2235.2 GiB | Backups, logs, headroom |
| spare (`00:01:00`) | 1x 300GB | global hot spare | 278GB, Hot Spare | n/a | Auto-rebuild for VD0 only |

The few GB shortfall on each volume is RAID metadata overhead. The sizes are the proof of
correctness, not the labels: RAID 0 across the same members would have reported ~1117GB
and ~3352GB respectively, so both volumes genuinely carry redundancy. Disk group numbering
skipping from #0 to #2 is a controller-internal artifact and is benign.

Sizes are grouped because a RAID array is capped by its smallest member; mixing a 1.2TB
drive into a 300GB array would waste 900GB of it.

### The hot spare covers VD0 only

A hot spare must be at least as large as the drive it replaces. This one is 278GB and the
VD1 members are 1117GB, so it is **not** an eligible rebuild target for VD1.

Operationally that means the two volumes fail differently:

- **A 300GB drive dies.** The spare takes over automatically and VD0 rebuilds unattended.
- **A 1.2TB drive dies.** VD1 keeps serving data but stays **degraded**, with no redundancy
  left, until a replacement 1.2TB drive is physically installed. A second failure in that
  window loses the volume.

This is a consequence of the mixed drive sizes, not a misconfiguration. It is why
`world.db` lives on VD0. Keeping a cold spare 1.2TB drive on hand would close the gap.

### RAID 10 requires manually declared spans

Ticking four disks and selecting `RAID 10` is rejected by this firmware:

> To create Virtual Disks for the selected RAID level, more than one span and an equal
> number of Physical Disks in each span is required.

RAID 10 is a nested level: mirror pairs (spans) that are then striped together. The PERC
HII will not infer the spans from a flat list of four ticked disks, so they have to be
declared by hand as **2 spans of 2 disks each**. Do that and creation proceeds normally.

The same error also appears from a plain miscount, for example three disks ticked instead
of four, so confirm the tick count before assuming it is the span issue.

RAID 6 across the same four disks was considered as a way to sidestep the span UI: it
yields identical usable capacity (~556GB) and survives any two failures rather than two
failures only in different mirror pairs. It was not needed once the spans were set, and
RAID 10 has far better write performance. Worth remembering as the fallback if this array
is ever rebuilt and the span UI proves troublesome again.

### Standing caveats

- **The 300GB drives are from 2013.** Roughly thirteen years of spin time, well past
  design life. SMART is clean today. Assume one will fail: that is what the RAID 10 and
  the hot spare are for, and it is why Stage L's off-box `world.db` backup is not
  optional.
- **RAID is not a backup.** It survives a dead drive. It does not survive a bad `rm`, a
  corrupted write, or the building burning down.
- **Write Back caching needs a healthy controller battery.** On hardware this old the BBU
  may be dead. See B7 and the note below.

### Write Back is not proof of a healthy battery

The controller accepted `Write Back` for both volumes. That is a positive signal but not
confirmation, and it should not be recorded as one.

A PERC lets you *configure* Write Back regardless of battery health. If the BBU is dead or
missing, the controller falls back to Write Through at runtime while the **configured**
policy still displays as Write Back. The configuration screen therefore cannot distinguish
a healthy battery from a dead one.

Nothing is blocked by this and nothing needs rebuilding. It is resolved in Stage I from
Ubuntu using Dell's `perccli`, which reports battery state and each volume's **current**
cache policy rather than its configured one. If the battery turns out to be dead, the
consequences are reduced write performance and a tighter `world.db` backup cadence in
Stage L, not data loss, provided `Force Write Back` was never selected.

---

## Stage A: Pre-flight

- [ ] **A1.** In the PERC utility, open `Configuration Options > Physical Disk Management >
  View Physical Disk Properties`, then open the **Select Physical Disk** dropdown at the
  top. Expected: all 8 drives listed, each with its state shown inline. notes:
- [ ] **A2.** Record the state of every drive. Expected: all `Ready`. Any drive reading
  `Foreign` still carries the previous owner's RAID metadata and must be cleared before it
  can be used. notes:
- [ ] **A3.** Record which disk IDs are 278GB and which are ~1117GB, so they can be told
  apart during selection in Stage B and C. notes:

> ### CHECK IN 1
> Report all 8 states plus the disk IDs grouped by size. A `Foreign` drive stops the run
> until it is cleared via **Foreign Configuration Management**.

---

## Stage B: Create VD0, the OS volume

- [x] **B1.** Go to `Configuration Options > Virtual Disk Management > Create Virtual Disk`.
  notes:
- [x] **B2.** Set **Select RAID Level** to `RAID 10`. notes:
- [x] **B3.** In **Select Physical Disks**, tick exactly **four** 300GB drives. Leave the
  fifth 300GB and all three 1.2TB unticked. notes:
- [x] **B3a.** Declare the spans by hand: **2 spans, 2 disks each**. Without this the
  create fails with the span error quoted above. notes:
- [x] **B4.** Set **Virtual Disk Name** to `os`. notes:
- [x] **B5.** Leave **Virtual Disk Size** at maximum. Expected: roughly 556GB. notes:
- [x] **B6.** Leave **Stripe Element Size** at `64KB`. notes:
- [x] **B7.** Set **Write Policy** to `Write Back`. If the controller refuses it or warns
  about the battery, use `Write Through` instead. Never pick `Force Write Back`: it
  overrides the battery safety check, which is a real way to lose `world.db` on a power
  cut. notes:
- [x] **B8.** Set **Default Initialization** to `Fast`. notes:
- [x] **B9.** Select **Create Virtual Disk**. Confirm the destructive-write warning
  ("Creating Virtual Disks will cause the data on the associated Physical Disks to be
  permanently deleted"), after checking the summary lists the four 300GB disks and not
  any 1.2TB. notes:
- [x] **B10.** Verify the reported size of VD0. Expected **~556 to 559GB**. A reading near
  **1.09TB** means the spans were mis-declared and the controller built RAID 0, giving the
  volume that holds `world.db` no redundancy at all. Delete and rebuild if so.
  notes: PASS. 557GB, RAID10, Ready.

> ### CHECK IN 2
> Report whether it created cleanly, the size it reported, and which write policy it
> accepted.
>
> The size is the load-bearing answer: because B3a requires spans to be declared by hand,
> a mis-set span silently yields a striped volume rather than a mirrored-striped one, and
> the only visible symptom is the capacity.
>
> The write policy is weaker evidence than it first appears. See "Write Back is not proof
> of a healthy battery" below.

---

## Stage C: Create VD1, the storage volume

- [x] **C1.** **Create Virtual Disk** again. notes:
- [x] **C2.** Set **Select RAID Level** to `RAID 5`. notes:
- [x] **C3.** In **Select Physical Disks**, tick the **three 1.2TB** drives. notes:
- [x] **C4.** Set **Virtual Disk Name** to `data`. notes:
- [x] **C5.** Apply the same settings as B6 through B8. notes:
- [x] **C6.** Create and confirm. Expected: roughly 2.2TB usable. notes:

> ### CHECK IN 3
> Report the size. Near 3.3TB instead of 2.2TB means it built RAID 0, which has no
> redundancy, and we delete and redo it.

---

## Stage D: Hot spare and boot cleanup

- [x] **D1.** Go to `Physical Disk Management > Select Physical Disk Operations`. notes:
- [x] **D2.** Select the leftover 300GB drive. notes:
- [x] **D3.** Choose **Assign Global Hot Spare**. Expected: its state changes to
  `Hot Spare`. notes:
- [x] **D4.** Escape out to `System BIOS > Boot Settings > UEFI Boot Settings`. notes:
- [x] **D5.** Under **Boot Option Enable/Disable**, untick
  `Unavailable: Windows Boot Manager`. It is inert, but leaving it clutters the boot list
  and invites confusion later. notes:
- [x] **D5a.** In `System BIOS > Boot Settings`, confirm **Boot Mode** is `UEFI`. Leave it
  there. notes:
- [x] **D6.** Save changes and exit System Setup. notes:

#### Boot Mode: keep UEFI, and decide it now

Do not switch to BIOS/legacy mode. Three reasons, in order:

1. The install USB is written `GPT` / `UEFI` in E4. A legacy-mode box will not boot it.
2. Boot mode is effectively permanent once an OS is installed, because the installer lays
   down a mode-specific bootloader. Changing it afterwards produces an unbootable machine
   and a reinstall.
3. Legacy mode exists on the R720 for pre-2012 operating systems. Ubuntu Server installs
   and boots cleanly under UEFI on this hardware.

The one thing legacy mode offers is the `Ctrl+R` PERC utility during POST, which is moot
here since all RAID work was done through the UEFI HII.

> ### CHECK IN 4 — PASSED 2026-08-05
> Capture the physical disk list showing the hot spare, and confirm Boot Mode reads `UEFI`.
> RAID configuration is then done permanently.
>
> **Result:** `Physical Disk 00:01:00: SAS, 278GB, Hot Spare`. Boot Mode `UEFI`. Both
> volumes `Ready` at the expected sizes. Storage configuration closed.

---

## Stage E: Build the install USB

Runs on the Windows dev box, in parallel with Stages A through D.

- [x] **E1.** Download **Ubuntu Server 26.04 LTS** from `ubuntu.com/download/server`.
  Server edition, not Desktop. Roughly 3GB. If a `26.04.1` point release is listed, prefer
  it. notes: Ubuntu 26.04 LTS = current version.
- [x] **E2.** Download **Rufus 4.15** (released 2026-06-30) from `rufus.ie/downloads`.
  Take **`rufus-4.15p.exe`**, the portable x64 build. Not the `_x86` (32-bit) or `_arm64`
  builds. No installation required. notes:
- [x] **E3.** Insert a USB stick of 8GB or larger. **Its contents will be erased.** notes:
- [x] **E4.** In Rufus, confirm **Device** is the intended stick, leave **Boot selection**
  on `Disk or ISO image`, and click **SELECT** to pick the Ubuntu ISO. notes:
- [x] **E4b.** Only after the ISO loads do **Partition scheme** and **Target system**
  unlock; before that they sit greyed at `MBR` / `BIOS (or UEFI-CSM)`. Set them to **`GPT`**
  and **`UEFI (non CSM)`** and verify, since Rufus's auto-selection is usually right but not
  guaranteed. Leaving the MBR/BIOS defaults produces a stick that will not boot a
  UEFI-mode R720, and the symptom is the USB simply never appearing in the F11 boot menu.
  notes:
- [x] **E4c.** Leave **Format Options** at their defaults: volume label as derived from the
  ISO (cosmetic only), **File system `FAT32`**, cluster size `16 kilobytes`. FAT32 is not
  optional: UEFI firmware is required to read it, and that is what makes the stick bootable
  here. Leave **Persistent partition size** at `0 (No persistence)`; persistence is for
  live sessions that save changes, not for an installer. notes:
- [x] **E4a.** When Rufus detects the ISOHybrid image and asks how to write it, choose
  **"Write in ISO Image mode (Recommended)"**. That is the mode that respects the `GPT` /
  `UEFI` selection from E4. Rufus may first ask to download updated GRUB files; allow it,
  which needs internet access. A final warning that the drive will be wiped follows. notes:
- [x] **E5.** Click START and wait for completion. notes:

> **Source hygiene.** Download Rufus only from `rufus.ie/downloads` or the official
> `pbatard/rufus` GitHub releases. Searching for it surfaces "Rufus Crack / Key / Full
> Version" downloads, which are malware trading on the name: Rufus is free and open source,
> has never been paid, and has no licence key.

**Standard vs portable `p` build.** The two are byte-for-byte identical binaries; Rufus
picks its mode by checking whether its own filename contains a `p`, the same trick BusyBox
uses to act as different utilities. Both persist settings across runs on a given machine.
The standard build writes them to the Windows registry, the `p` build to a `rufus.ini`
beside the executable, so the portable build's real advantage is carrying settings
*between* machines. Either produces an identical USB.

The `p` build is specified here purely so a single-use tool leaves no registry keys behind.
Grabbing the standard build instead changes nothing about the result.

### OS version choice, and whether this hardware can run it

**Ubuntu Server 26.04 LTS "Resolute Raccoon"**, released 2026-04-23 on kernel 7.0.
Supported to April 2031 standard, up to 10 years on a free Ubuntu Pro plan. It is the
right pick over 24.04 for a deployment starting now: same install effort, two extra years
of support runway.

Two hardware-compatibility questions were checked before committing, because the R720 is
2012-era and a wrong answer means an installer that boots to nothing useful.

**CPU baseline: clear.** Ubuntu 25.10 introduced `x86-64-v3` architecture variant packages,
which require AVX2 and therefore Haswell (2013) or newer. The R720's Xeon E5-2600 v1/v2
are Sandy/Ivy Bridge, pre-Haswell, with no AVX2. Had that baseline become mandatory this
box could not run 26.04 at all. It has not: the `x86-64-v3` packages are opt-in
alternatives and the standard baseline is unchanged, so the R720 runs normal packages.

**RAID controller driver: expected to work, not fully verified.** The PERC H710P Mini is
an LSI MegaRAID SAS2208 ("Thunderbolt") and is driven by the in-tree, Broadcom-maintained
`megaraid_sas` module, which has long supported that chipset. The specific kernel 7.0
support matrix could not be confirmed from documentation.

> **Contingency.** If the installer reaches the disk-selection step and lists **no disks**,
> that is the driver symptom, not a RAID misconfiguration. The storage is known good as of
> Check In 4. Fall back to **Ubuntu Server 24.04 LTS**, which is a known-good pairing with
> this controller generation, and note it here.

---

## Stage F: Boot the installer

- [x] **F1.** Plug the USB into a **rear** USB port on the R720. notes:
- [x] **F2.** Power on and press **F11** for Boot Manager at the prompt. notes:
- [ ] **F3.** Choose the one-time UEFI boot menu, then select the USB device. notes:
- [x] **F4.** Wait. The R720's ports are USB 2.0, so this is slow; give an apparently
  frozen screen several minutes before assuming a fault. Expected: the Ubuntu installer
  language select. notes:

> ### CHECK IN 5 — PASSED 2026-08-05
> Confirm the installer was reached.
>
> **Result:** GRUB menu reached, offering `Try or Install Ubuntu Server` / `Boot from next
> volume` / `UEFI Firmware Settings`. The presence of a **UEFI Firmware Settings** entry is
> itself confirmation the stick booted in UEFI mode, validating D5a and E4b. The
> `megaraid_sas` contingency above was not needed.

---

## Stage G: Install Ubuntu

> **This install is running with no network attached.** The server could not be cabled to
> the router at install time. That is supported, but it changes several answers below and
> defers all networking to Stage H. See "Installing offline" before starting.

- [x] **G1.** At the GRUB menu choose **Try or Install Ubuntu Server**. notes:
- [x] **G2.** Language, then keyboard layout. notes:
- [x] **G3.** Installation type: standard **Ubuntu Server**, not the minimized variant. notes:
- [x] **G4.** Network: no link present, so select **Done** without configuring an
  interface. Deferred to Stage H. notes:
- [x] **G5.** Proxy: leave blank. notes:
- [x] **G6.** Ubuntu archive mirror: this step will fail to reach the mirror and may hang a
  while before reporting it. Expected with no link. Continue past it. notes:
- [x] **G7.** Disk selection: choose the **557GB `os`** volume. **Not** the 2234GB `data`
  volume. notes:
- [x] **G8.** Accept LVM, then **expand the root logical volume to consume the full
  volume** before continuing. See "The guided LVM trap" below. notes:
- [x] **G9.** Storage summary: destructive confirmation. Verify the target is the 557GB
  volume and that root spans it. notes:
- [x] **G10.** Profile: your name, a server hostname, username, password. notes:
- [x] **G11.** Ubuntu Pro: skip. notes:
- [x] **G12.** **Install OpenSSH server: YES.** This works offline because the package ships
  on the ISO. Skip **import SSH key**, which requires internet; the key is added by hand in
  Stage H. notes:
- [x] **G13.** Featured server snaps: select **none**. They would fail to download. notes:
- [x] **G14.** Let it install, then reboot and **remove the USB stick**. notes:
- [ ] **G15.** At the first login, verify the install before moving on:

  ```bash
  lsblk                              # both volumes present: ~557G with LVM, ~2.2T bare
  df -h /                            # root should be ~545G, not ~98G
  ip -br link                        # record interface names for Stage H
  sudo dmesg | grep -i megaraid      # confirms the PERC driver bound
  ```
  notes:

> ### CHECK IN 6 — PASSED 2026-08-05
> Confirm the system boots to a login prompt and root came out full size.
>
> **Result:** booted to `Ubuntu 26.04 LTS projectdawn tty1`, kernel `7.0.0-14-generic
> x86_64`. MOTD reports `Usage of /: 2.0% of 544.92GB`, which is the proof the G8 LVM
> expansion took; the guided default would have shown ~98GB here. cloud-init generated ECDSA
> and ed25519 SSH host keys, confirming **OpenSSH server installed correctly offline** from
> the ISO. The Stage E `megaraid_sas` contingency was never needed: the system boots from
> the H710P under kernel 7.0.

---

## Stage G2: Format and mount the `data` volume

Done 2026-08-05, offline. VD1 needs no network to bring into service, so it was completed
while Stage H stayed blocked.

- [x] **G2.1.** `sudo mkfs.ext4 -m 0 -L data /dev/sdb` notes: 585760768 4k blocks =
  2.182 TiB, matching `lsblk` and the PERC's 2234GB. Filesystem UUID
  `efc84de3-e91e-4eaa-acc9-b6c7ac7dd75b`.
- [x] **G2.2.** `sudo mkdir -p /data` notes:
- [x] **G2.3.** Append to `/etc/fstab` **by UUID**, never `/dev/sdb`, since device letters
  can reorder between boots:

  ```
  UUID=efc84de3-e91e-4eaa-acc9-b6c7ac7dd75b  /data  ext4  defaults,nofail  0  2
  ```
  notes: added via `echo ... | sudo tee -a /etc/fstab` to avoid editing existing lines.
- [x] **G2.4.** `sudo mount -a`, then `df -h /data`. notes: `/dev/sdb 2.2T 2.1M 2.2T 1%
  /data`.
- [x] **G2.5.** `sudo systemctl daemon-reload`. `mount -a` emits a hint that systemd still
  holds the pre-edit `/etc/fstab`; systemd generates mount units from it and its cache is
  stale until reloaded. Not an error, but leaving it is sloppy. notes: also satisfied by
  the G2.6 reboot, which regenerates the units regardless.
- [x] **G2.6.** Reboot and re-check `df -h /data`. This is the only real proof the fstab
  entry is correct. `nofail` makes the test safe. notes: PASS. `uptime` read `up 8 min`,
  confirming a genuine post-reboot check, and `/data` remounted on its own at 2.2T.

### Why `-m 0` and why `nofail`

**`-m 0`** disables ext4's default 5% reserved-blocks allocation. That reservation exists so
system daemons can still write when a root filesystem fills; it is pointless on a pure data
volume, and at this size it would strand roughly **110GB**. The proof it worked is `df`
reporting Size and Avail both as `2.2T` rather than 2.2T against 2.1T.

**`nofail`** tells systemd to carry on booting if the volume cannot be mounted. Without it a
missing or failed data volume drops the machine into emergency mode at boot, which on a
headless server means physically attaching a monitor to recover. Correct for a data volume,
never correct for root.

### Installing offline

Skipping the network step is supported and nothing about it is permanent. The costs are:

- No package updates during install, so a full `apt update && apt full-upgrade` is required
  once the link exists.
- No SSH key import, so the key is added manually in Stage H.
- No snaps.
- **No SSH at all until Stage H is done.** The physical console is the only way into this
  machine, so the monitor and keyboard must stay attached until networking works.

### The guided LVM trap

Ubuntu's guided LVM setup does **not** allocate the whole volume to root. It creates a
modest root logical volume and leaves the remainder of the volume group unallocated, and
the shortfall is easy to miss for months.

**Hit on this install, 2026-08-05.** The guided default proposed:

```
/ ................... 100.000G   new ext4   new LVM logical volume
ubuntu-vg (new) ..... 554.695G   LVM volume group
   free space ....... 454.695G
```

That is 82% of the array left stranded. Fixed by selecting the **►** on the `ubuntu-lv`
row under USED DEVICES, choosing **Edit**, and setting Size from `100.000G` to the maximum
`554.695G`.

**How to verify the fix.** `ubuntu-vg` should vanish from **AVAILABLE DEVICES** entirely,
because it no longer has free extents to offer. The FILE SYSTEM SUMMARY should show `/` at
the full VG size. A few MB of difference between the PV partition (554.698G) and the VG
(554.695G) is LVM metadata and is expected.

If it is ever missed, it is recoverable without a reinstall via `lvextend` plus
`resize2fs`, since the space simply sits free in the volume group. LVM is worth keeping
rather than opting out: it is what makes that later resize possible at all.

### Why not LUKS encryption

The guided screen offers to encrypt the LVM group. Declined deliberately: LUKS requires a
passphrase typed at the physical console on **every boot**, so a power cut would leave the
game server down until someone walks over to the machine. The threat it defends against is
physical theft of the drives, which is not the risk model here.

---

## Stage H: Network, SSH, and the deferred upgrade

Started 2026-08-06, after the server was physically relocated to the basement and cabled
to the network. This stage carries everything the offline install deferred.

Careful not to cable the **dedicated iDRAC port**, which is a physically separate jack and
gives the OS no network.

- [x] **H1.** Cable NIC **Port 1** (`b8:ca:3a:f7:35:92`, `eno1`) to the router. notes:
- [x] **H2.** Confirm `eno1` picked up an address: `ip -br addr`. The `dhcp4: true` staged
  in Stage G3 means this happens on its own when carrier appears. notes:
- [x] **H3.** Confirm DNS resolves: `ping -c3 archive.ubuntu.com`. Test this **separately**
  from raw IP connectivity; a DNS failure and a routing failure look similar but have
  unrelated fixes. notes: resolved, ~110ms RTT, 1 of 3 ICMP dropped.
- [x] **H4.** Confirm local link health against the gateway, where loss actually means
  something:

  ```bash
  ping -c10 $(ip route | awk '/default/ {print $3}')
  ```
  notes: PASS. 10/10 received, 0% loss, rtt min/avg/max 0.529/1.449/3.645 ms. This also
  cleared the H3 ICMP drop as `archive.ubuntu.com` deprioritizing ICMP rather than a local
  fault.
- [x] **H5.** SSH in from the dev box: `ssh wrightt@<ip>`. notes: first attempt returned
  `Connection closed by <ip>`; an immediate retry reached the password prompt and
  succeeded. Presumed `sshd` still settling post-boot. Investigate only if it recurs.
- [ ] **H6.** Set a **DHCP reservation** on the router for `b8-ca-3a-f7-35-92` so the
  address cannot drift. Everything downstream depends on a stable address, including the
  Stage K port forward. notes:
- [x] **H7.** Set up SSH **key-based auth** so the password is no longer typed. Prerequisite
  for anything automated later, notably the Stage L backups. notes: ed25519 keypair
  generated **on the dev box**, public half appended to `~/.ssh/authorized_keys`. Empty
  passphrase for now; one can be added later with `ssh-keygen -p -f <keyfile>` without
  invalidating the installed public key, since that re-encrypts the private key in place
  and leaves the pair itself unchanged.
- [x] **H8.** Run the deferred upgrade: `sudo apt update && sudo apt full-upgrade -y`.
  Expect a large batch coming from an offline install, and a purple `needrestart` prompt;
  accept the defaults. Restarting `ssh` does not drop existing sessions. notes:
- [x] **H9.** Check `ls /var/run/reboot-required` and reboot if present. A newer kernel than
  the ISO shipped is near certain. Safe over SSH now that `/data` mounts on its own. notes:
  rebooted clean. Passwordless SSH worked from cold, `/data` remounted on its own, and no
  further reboot was pending.
- [x] **H10.** Only once key-based SSH is proven: detach the monitor and keyboard. notes:
  unblocked 2026-08-07.

### Generate the key on the client, not the server

The private key must live on the machine you connect **from**. A pair generated on the
server cannot help the dev box prove who it is. A server-side key is wanted eventually, for
Stage I to clone the private GitHub repo, but that is a separate key for a separate job.

The trap is that an SSH session looks identical to a local terminal. Check the path in the
`ssh-keygen` prompt: `/home/wrightt/.ssh/...` means you are on the server and should abort;
`C:\Users\tyler/.ssh/...` means you are on the dev box and should continue.

### Installing the public key from PowerShell

```powershell
$key = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
ssh wrightt@<ip> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$key' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

Read the file into a variable and interpolate it rather than piping the file into `ssh`.
PowerShell injects CRLF line endings and a BOM into pipes, which silently corrupts
`authorized_keys` and produces a baffling "the key just doesn't work" symptom.

The `chmod` values are load-bearing: `sshd` ignores `authorized_keys` **silently** when the
file or its directory is group- or world-writable, so a permissions mistake presents exactly
like a missing key.

Watch the closing `"`. Omitting it drops PowerShell to a `>>` continuation prompt instead of
running anything; Ctrl+C and retype.

---

## Stage H2: Baseline hardening

Done 2026-08-07, while the box is still **LAN-only**. Nothing forwards to it from the
internet yet, so real risk today is low; this is done now because it is cheap and because
it has to be correct *before* Stage K opens a hole through the router.

> **The rule that prevents disasters.** For any change to SSH or the firewall, keep the
> current session open and test from a **second** terminal. If the change locks you out,
> that open session is the fix. Without it, it is a trip to the basement with a monitor.

- [x] **H2.1.** Firewall, default deny inbound. **Order is not optional:** allow SSH
  *before* enabling, or the firewall cuts your own connection as it comes up.

  ```bash
  sudo ufw allow OpenSSH      # app profile from /etc/ufw/applications.d/, resolves to 22/tcp
  sudo ufw enable
  sudo ufw status verbose
  ```
  notes: active. `deny (incoming), allow (outgoing)`, 22/tcp allowed on v4 and v6.
- [x] **H2.2.** Verify with a **fresh** SSH connection, not the open session. An established
  connection survives a firewall change regardless, so it proves nothing. notes:
- [x] **H2.3.** Disable SSH password auth. Safe now that key auth is proven across a cold
  reboot.

  ```bash
  sudo tee /etc/ssh/sshd_config.d/10-hardening.conf > /dev/null <<'EOF'
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  PermitRootLogin no
  EOF
  ```
  notes: filename prefix `10-` is load-bearing, see below.
- [x] **H2.4.** Validate before restarting anything:

  ```bash
  sudo sshd -t     # parses config; silence means valid
  sudo sshd -T | grep -iE "passwordauthentication|permitrootlogin|kbdinteractiveauthentication|pubkeyauthentication"
  ```
  notes: returned `permitrootlogin no` / `pubkeyauthentication yes` /
  `passwordauthentication no` / `kbdinteractiveauthentication no`. Correct.
- [x] **H2.5.** `sudo systemctl restart ssh`, then test **both** directions from a second
  window. notes: key login works; the forced-password probe returns
  `Permission denied (publickey).` with no prompt, which is the real proof.
- [x] **H2.6.** Automatic security updates, worth more on a box that sits unattended:

  ```bash
  sudo apt install unattended-upgrades
  sudo dpkg-reconfigure --priority=low unattended-upgrades   # answer Yes
  ```
  notes: enabled. Ubuntu's shipped config shows `-updates`, `-proposed` and `-backports`
  commented out, so only the security pockets apply automatically.
- [x] **H2.6a.** Make the no-auto-reboot behaviour **explicit** rather than inherited:

  ```bash
  sudo sed -i 's|^//Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "false";|' /etc/apt/apt.conf.d/50unattended-upgrades
  ```
  notes: confirmed active. The setting shipped commented out, which means the built-in
  default (`false`) applied. Relying on that default is a bad bet for a game host: a future
  package update that changes it would silently start rebooting the box overnight, and
  "the server rebooted itself at 2am mid-raid" is a bad way to find out. With it false,
  kernel updates install but wait for a deliberate reboot at a time nobody is playing.
- [x] **H2.7.** Audit what listens: `sudo ss -tlnp`. notes: baseline recorded below.

### Listening-port baseline, 2026-08-07

Taken before the game server exists. Diff against this later; anything new holding a port
is worth explaining.

```
127.0.0.53%lo:53   systemd-resolve    loopback only, not reachable
127.0.0.54:53      systemd-resolve    loopback only, not reachable
0.0.0.0:22         sshd               reachable
[::]:22            sshd               reachable
```

SSH is the only network-reachable service. The `sshd` rows also list
`("systemd",pid=1,...)` holding the socket, which confirms socket activation is genuinely
in use here.

### Why the file is named `10-` and not `99-`

`sshd_config` is **first-match-wins**, and `Include /etc/ssh/sshd_config.d/*.conf` sits near
the top of the main file, before the Authentication section. Ubuntu's own comment in
`sshd_config` spells out the consequence:

> configuration snippet files are processed in lexical order, so options defined in files
> with names that sort earlier take precedence.

The image ships `50-cloud-init.conf` containing `PasswordAuthentication yes`. A file named
`99-hardening.conf` would sort **after** it and be silently ignored: sshd would restart
without error and password auth would still be on. `10-` sorts earlier and therefore wins.

Everything in the main `sshd_config` relating to this was commented out, so those lines were
never in play. `KbdInteractiveAuthentication no` was already uncommented and active there;
repeating it costs nothing.

### Why `KbdInteractiveAuthentication` is not redundant

`UsePAM yes` is active. With PAM in play, keyboard-interactive can still present a password
prompt even when `PasswordAuthentication no` is set. Setting only the obvious option is an
incomplete lockdown.

`PermitRootLogin` had been left commented, so the compiled default `prohibit-password`
applied, which still permits root login **by key**. Set to `no` since access is via
`wrightt` plus `sudo`.

### Verifying the lockdown, not just that keys work

```powershell
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password wrightt@<ip>
```

Forces the client to skip the key. The pass condition is an immediate
`Permission denied (publickey).` with **no password prompt**. A prompt means the change did
not take.

### Note on systemd socket activation

Ubuntu now socket-activates SSH by default, so each connection spawns a fresh `sshd` that
re-reads the config; changes can be live before any restart. The socket regeneration dance
described in `sshd_config` applies only to `Port`, `AddressFamily`, and `ListenAddress`,
none of which were touched here.

### Deferred to Stage K

`fail2ban` adds little while password auth is off, and earns its place once SSH or the game
ports face the internet.

### Hostname does not resolve on this network

`ping projectdawn` fails from both WSL and PowerShell, as do the `.local`, `.lan` and
`.home` suffixes. The router does not register DHCP hostnames in DNS. This is a router
behaviour, not a fault, and says nothing about server health.

Find the box by its MAC instead. From PowerShell, substituting the real subnet:

```powershell
$net = "192.168.1"
1..254 | ForEach-Object { ping -n 1 -w 100 "$net.$_" | Out-Null }
arp -a | Select-String "b8-ca-3a"
```

The sweep populates the ARP table even against a host that ignores ping, because ARP
resolution precedes the ping itself. Once H6 pins the address this stops mattering.

### Verifying the SSH host key

On first connect, compare the offered fingerprint against the ed25519 host key cloud-init
generated during install, which begins `SHA256:zjdByJdPxvr3+oaI/`. A fingerprint that looks
nothing like it means a **different machine** answered on port 22, not the server. Clear the
bad entry with `ssh-keygen -R <ip>` before retrying.

---

## Stage I: Toolchain, source, build

Written 2026-08-07 against the actual server repo at `F:\Projects\server`, not from memory.
Needs no router access, so it is not blocked by the outstanding H6.

### What the repo actually requires

| Fact | Source | Consequence |
|---|---|---|
| `channel = "1.95.0"` | `rust-toolchain.toml` | **Do not pin a version by hand.** `rustup` reads this file and installs the right toolchain on the first `cargo` invocation inside the repo. |
| `default-members` excludes `gdext-net` | root `Cargo.toml` | A plain `cargo build --release` builds only the server crates. The GDExtension is the *client's* and must not be built here; the manifest comment says it is opted into explicitly for exactly this reason. |
| Only native dep is `libsqlite3-sys` | `Cargo.lock` | It compiles SQLite from source, so a C compiler is all that is needed. No `libssl-dev`: there is no `openssl-sys`, `ring`, or `native-tls` in the lockfile. |
| Remote is `https://github.com/UsuallyBloated/Project_Dawn_server.git` | `git remote -v` | The repo is **private over HTTPS**, so cloning needs a Personal Access Token, or the remote switched to SSH with a deploy key. |

- [x] **I1.** Build prerequisites:

  ```bash
  sudo apt install -y build-essential curl git pkg-config
  ```
  notes: the `WARNING: apt does not have a stable CLI interface` banner is cosmetic, and
  the trailing `Scanning processes... / Scanning linux images...` lines are `needrestart`
  running after the install finished. Both look like a hang and are not one.
- [x] **I2.** Install `rustup`. Do **not** use the distro `rustc`; it will not honour the
  toolchain pin.

  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  . "$HOME/.cargo/env"
  rustc --version
  ```
  notes: `rustc 1.97.1`. The `-s -- -y` matters: piping the installer into `sh` leaves it
  with no terminal, so without `-y` it aborts with
  `error: Unable to run interactively`. The `-s --` tells `sh` to read the script from
  stdin and pass everything after it to that script.
- [x] **I3.** Clone the server repo via the deploy key, see below.

  ```bash
  git clone git@github.com:UsuallyBloated/Project_Dawn_server.git ~/server
  ```
  notes: cloned clean.
- [x] **I4.** Build. Cold build of the whole dependency tree plus SQLite from source.

  ```bash
  cd ~/server && cargo build --release
  ```
  notes: `Finished release profile [optimized] target(s) in 2m 38s`. `nproc` reports **32**
  threads (dual 8-core Xeons with HT); cargo parallelizes across crates and used all of
  them, so this went far quicker than 2012 hardware suggests.
- [x] **I5.** Confirm the toolchain that actually got used, rather than assuming:

  ```bash
  rustc --version    # expect 1.95.0, resolved from rust-toolchain.toml
  ```
  notes: PASS. Outside the repo `rustc` reports 1.97.1; the first invocation **inside**
  `~/server` triggered `syncing channel updates for 1.95.0` and switched automatically.
  The pin works, which is exactly why no version should be installed by hand.
- [x] **I5a.** Prove the binary runs *and* that the netcode-key guard is intact, in one
  step: `./target/release/projectdawn-server` with no config should **refuse to start**.
  notes: PASS. Exits with `Error: loading server config / Caused by:
  PROJECTDAWN_NETCODE_KEY is required`. A refusal here is the pass condition, not a
  failure.
- [ ] **I6.** Settle the open controller-battery question. See below. notes:

### Do not paste markdown code fences into the shell

This cost real time on 2026-08-07 and the failure mode is genuinely confusing, so it is
worth knowing.

Pasting a fenced block from chat or docs, including the ```` ```bash ```` and closing
```` ``` ```` lines, feeds backticks to bash as **command substitution**. The shell then
tries to execute the *captured output* as a command, and can leave you sitting inside a
nested shell that silently consumes keystrokes as stdin instead of running them.

The symptom is that **every command returns nothing**: no output, no error, not even from
`echo hello`. That is diagnostic in itself, because `echo` is a builtin that touches no
files and cannot legitimately print nothing. Buffered output from the wedged state flushes
only when you `exit` the nested shell.

Copy the command text alone, never the fence lines. In PowerShell's SSH window, right-click
pastes.

### Cloning a private repo onto the server

Two options.

**HTTPS with a Personal Access Token.** Matches the existing remote, nothing to reconfigure.
Create a fine-grained PAT on GitHub with read-only Contents access to
`Project_Dawn_server`, then use it as the password when `git` prompts. Store it with
`git config --global credential.helper store` if you do not want to paste it on every pull,
noting that helper writes the token in plaintext under `~/.git-credentials`.

**SSH with a deploy key.** Generate a keypair *on the server* (this is the legitimate use for
the server-side key nearly created by accident during Stage H), add the public half to the
repo's Deploy Keys on GitHub as read-only, and clone the `git@github.com:` URL instead. No
long-lived token on disk, and the key is scoped to one repository.

Prefer the deploy key. It is read-only, repo-scoped, and revocable independently of the
account.

### Answering the controller battery question

`perccli` is **not** in the Ubuntu archive; it is a Broadcom/Dell download, so `apt install
perccli` will fail. Two realistic routes:

1. **iDRAC web UI.** The R720 has iDRAC7 on a dedicated port. Its storage page reports
   controller battery state with no software installed on the host at all. Easiest path, and
   it is worth configuring anyway for remote power control on a basement machine.
2. **Download `perccli` from Dell support** and install the `.deb` by hand.

What we are looking for is the battery's health and each volume's **current** cache policy,
which is what distinguishes a genuinely healthy BBU from the configured-but-ignored
`Write Back` recorded in Stage B. See "Write Back is not proof of a healthy battery" above.

### Ports and config discovered for later stages

From `.env.example` and `crates/projectdawn-server/src/config.rs`:

| Variable | Default | Notes |
|---|---|---|
| `PROJECTDAWN_AUTH_BIND` | `0.0.0.0:8765` | Auth WebSocket, **TCP**. The launcher connects here. |
| `PROJECTDAWN_WORLD_BIND` | `0.0.0.0:7777` | World renet listener, **UDP**. |
| `PROJECTDAWN_WORLD_ENDPOINT` | `127.0.0.1:7777` | **The deployment trap.** This is what the server *advertises* to clients in `LoginOk.world_endpoint`. Left at the loopback default, every remote client is told to connect to itself and the world silently fails to join even though auth succeeds. Must be set to an address reachable from the player's machine. |
| `PROJECTDAWN_NETCODE_KEY` | none, **required** | 64-char lowercase hex. The server refuses to start without it, deliberately: there is no default-key fallback, since a default would let anyone who knew it mint accepted connection tokens. Generate with `openssl rand -hex 32`. Server-side secret only; clients receive signed tokens, never the key. |
| `PROJECTDAWN_DATABASE_URL` | `sqlite://world.db?mode=rwc` | Migrations apply on boot. |
| `PROJECTDAWN_MIN_CLIENT_VERSION` | `0.1.0` | Older logins rejected. |

So Stage K needs **TCP 8765** and **UDP 7777**, and nothing else.

### Tailscale is a live alternative to port forwarding

`.env.example` already anticipates it, referring to setting `PROJECTDAWN_WORLD_ENDPOINT` to
a tailnet IP for the friends-only alpha. Worth taking seriously given router credentials are
currently unavailable: Tailscale would let testers reach the server with **no port forwarding
and no inbound firewall holes at all**, at the cost of every player installing it and joining
the tailnet. That is a real trade against the "someone who is not you, from a machine that is
not yours" definition of done, so it is a decision to make deliberately at Stage K rather
than a default.

---

## Stage J: Production configuration

Written 2026-08-07 against `crates/projectdawn-server/src/{main,config}.rs`,
`src/world/connection.rs`, `src/bin/grant_gm.rs` and `.env.example`.

### Three facts that shape everything here

**The server loads `.env` itself.** `main()` calls a minimal loader before anything else.
It is deliberately simple: `KEY=VALUE` per line, `#` comments, and **no quoting magic**, so
values go in bare. Do not wrap them in quotes.

**It reads `.env` and `world.db` from the current working directory**, not from the binary's
location. Launching from the wrong directory yields a server with no config and a brand new
empty database. This becomes a hard `WorkingDirectory=` requirement on the Stage L systemd
unit, and it is why `grant_gm` must also be run from the repo root.

**`world.db` stays on VD0.** The default `sqlite://world.db?mode=rwc` resolves inside the
repo, which sits on the root filesystem: RAID 10 with hot-spare cover. `/data` is RAID 5
with **no** eligible spare, so it is for backups, not for live game state.

- [ ] **J1.** Generate the netcode key. 32 bytes, 64 hex chars:

  ```bash
  openssl rand -hex 32
  ```
  notes:
- [ ] **J2.** Create `.env` in the repo root from `.env.example` and set the values below.
  notes:
- [ ] **J3.** `chmod 600 .env`. It holds the netcode private key, which is the cryptographic
  gate on the world listener. `.env` is gitignored, so it cannot be committed by accident.
  notes:
- [ ] **J4.** Confirm `PD_DEV_CMDS` is **not** set: `env | grep PD_DEV_CMDS` should return
  nothing. notes:
- [ ] **J5.** First real boot. Read the startup log line, which prints `dev_cmds` explicitly.
  notes:
- [ ] **J6.** Register your account through the client, then grant it GM:

  ```bash
  cd ~/server && ./target/release/grant_gm <username> on
  ./target/release/grant_gm            # no args lists accounts + GM status
  ```
  notes:
- [x] **J7.** Re-log and confirm GM tools work while `dev_cmds=false`. notes: **PASS,
  2026-08-10, on the live host.** With the boot line reading `dev_cmds=false`, the server
  accepted two separate dev commands from the GM account:

  ```
  dev full restore (hp/mp/stamina) char_id=1 amount=187.0 new_hp=228.25
  GmGive applied owner=1 item_name=Iron Short Sword qty=1 leftover=0
  ```

  That is the Phase 1 keystone proven in production, not just by integration test and
  localhost playtest: dev commands off for everyone, tools granted to one account via
  `is_gm`, which rides the signed connect token and cannot be forged by a modified client.

  The same session also exercised, against the live database: the death and corpse-run loop
  (`corpse looted empty — despawned`), coin loot with split (`pot=20 ... do_split=true`),
  equipment with server-side stat recalculation (`EquipItem applied ... max_hp=229.0`), and
  combat with kill credit and XP (`kill credit granted ... base_xp=263`).

### `.env` values for this host

| Variable | Value | Why |
|---|---|---|
| `PROJECTDAWN_NETCODE_KEY` | the J1 output | Required; the server refuses to boot without it. No default-key fallback exists **by design**, since a known default would let anyone mint connect tokens the world listener accepts. Server-side secret only: clients receive signed tokens, never the key. |
| `PROJECTDAWN_AUTH_BIND` | `0.0.0.0:8765` | Auth WebSocket, TCP. |
| `PROJECTDAWN_WORLD_BIND` | `0.0.0.0:7777` | World renet listener, UDP. Bind all interfaces. |
| `PROJECTDAWN_WORLD_ENDPOINT` | **not** `127.0.0.1:7777` | See below. |
| `PROJECTDAWN_DATABASE_URL` | `sqlite://world.db?mode=rwc` | Relative to CWD. Keeps game state on VD0. |
| `PROJECTDAWN_MIN_CLIENT_VERSION` | `0.1.0` | Rejects older clients. |
| `RUST_LOG` | `projectdawn_server=info,sqlx=warn` | |

### Handling the netcode key

Treat it as a real secret: it is the cryptographic gate on the world listener, and anyone
holding it can mint connect tokens the server accepts. Never paste it into chat, tickets, or
commits. `chmod 600 .env`, and note `.env` is gitignored so it cannot be committed by
accident.

**Rotating it is free right now and expensive later.** The key lives entirely inside the
server process (auth mints tokens with it, the world listener validates them with it); no
client ever receives it and nothing else stores a copy. So before players exist, replacing
it is a one-line edit with zero coordination. Once sessions are live, rotating invalidates
every outstanding token and forces everyone to reconnect. If there is ever any doubt about
whether a key leaked, regenerate immediately rather than reasoning about exposure.

Verify the line is well-formed without printing the value:

```bash
grep -cE '^PROJECTDAWN_NETCODE_KEY=[0-9a-f]{64}$' .env    # expect 1
```

### `WORLD_ENDPOINT` is the deployment trap

This is what the server **advertises** to clients in `LoginOk.world_endpoint`; it is not a
bind address. Left at the `127.0.0.1:7777` default, every remote client is told to connect
to *itself*. Login succeeds, character list loads, and the world join silently fails. It
looks like a netcode bug and is a config mistake.

Its correct value depends on the Stage K access decision, so stage it:

- **LAN testing now:** the server's own LAN address, e.g. `192.168.x.x:7777`.
- **Port forwarding:** the public IP or DNS name.
- **Tailscale:** the tailnet IP, `100.x.y.z:7777`, which is what `.env.example` itself
  suggests for the friends-only alpha.

### The dev-command gate

`PD_DEV_CMDS` is enabled only when it equals exactly `"1"`. It is read once into a
process-wide `OnceLock`, so it is fixed at launch.

Production runs with it **unset**. Per-account GM then does the work:
`can_use_dev_cmds() = is_dev || is_gm`, where `is_gm` rides the signed connect token, so a
modified client cannot forge it.

There is no need to guess whether it is active. The boot log prints `dev_cmds=` on the
`starting projectdawn-server` line, and additionally emits a WARN when enabled:

> `PD_DEV_CMDS=1: dev commands (/give, dev spawn, HealSelf, GrantQuestXp) are ENABLED for
> ALL clients; do not run a public server with this set`

Seeing `dev_cmds=false` and no warning is the pass condition for J5.

`grant_gm` writes to `accounts.is_gm` and the world server reads the flag at login, so a
change takes effect on the account's **next** world login. Re-log a live session to pick it
up.

---

## Layout correction, 2026-08-10

Stages I and J were built at `~/server` running as `wrightt`. That is **not** where this
deployment lives. `scripts/projectdawn.service` in the server repo is written for a
different layout and one of its settings makes the `~/server` arrangement impossible:

```
ProtectHome=true
```

That renders `/home` invisible to the service, so a unit carrying it cannot run anything out
of a home directory. Together with `User=projectdawn`, `WorkingDirectory=/opt/projectdawn`
and `ReadWritePaths=/opt/projectdawn`, the unit expects:

```
/opt/projectdawn/
├── src/                  git clone, owned by the projectdawn service user
├── projectdawn-server    release binary, copied from src/target/release/
├── .env                  mode 600, holds the netcode key
└── world.db              created on first boot
```

Running a network-facing game server as a login account was the weaker choice anyway, so
this is a correction rather than a workaround. The `~/server` work still paid for itself: it
proved the build, established the GitHub deploy key, and caught the stale-branch problem
below.

### The stale-branch problem, caught 2026-08-08

The R720 cloned the repo's **default branch, `main`**, which sat at `98728ea` (26 June).
Active work was on `fix/xp-leveling-overflow`, **30 commits ahead**. The deployed binary was
therefore missing every Phase 1 exploit gate: `/give` gating (`a765573`), the per-account
`is_gm` keystone (`82f55a9`), the Respawn dead-check (`0d908d1`), attack-while-seated
(`3bb9b6d`), the CastSpell class/level gate (`a96826d`), the `Attack` weapon_path gate
(`9089b4b`), the melee swing-rate limit (`335b5b1`), the login rate-limiter (`a75d9d0` plus
three follow-ups), and server-authoritative procs (`b0bdbdd`).

**How it surfaced:** the startup log line was missing its `dev_cmds=` field. That field
arrived in `a765573`, so its absence dated the build. A one-word anomaly in a log line was
the only visible symptom of a six-week-old binary with no security gates in it.

**Standing check:** `dev_cmds=` present and reading `false` on the boot line means the build
is at least as new as that commit *and* that dev commands are off. Verify it after every
deploy, not just the first.

**Also:** a deploy host must track the branch that work actually happens on. `git clone`
takes the default branch, which is not necessarily the live one.

### Access model: Tailscale

Chosen 2026-08-10, matching what `deployment_linux.md` assumes throughout. Nothing is
exposed to the open internet, and the cleartext `ws://` auth socket is encrypted in transit
by WireGuard. UFW rules scope to the `tailscale0` interface rather than opening ports
globally.

Side effect worth noting: it retires the outstanding **H6 DHCP reservation** as a blocker.
The tailnet address is stable regardless of what the router does with leases, and SSH can
run over the tailnet too, which works from outside the LAN as well.

Cost: every tester installs Tailscale and joins the tailnet. That is a real deviation from
the "someone who is not you, from a machine that is not yours" definition of done, and is
accepted deliberately for the friends build.

### As deployed, 2026-08-10

Migrated off `~/server` and onto the layout `scripts/projectdawn.service` expects. Follow
`server/docs/deployment_linux.md` for the authoritative procedure; this records what was
actually done here.

| | |
|---|---|
| Service account | `projectdawn`, system user, home `/opt/projectdawn` |
| Source | `/opt/projectdawn/src`, cloned with **`-b fix/xp-leveling-overflow`** |
| Binary | `/opt/projectdawn/projectdawn-server` |
| Config | `/opt/projectdawn/.env`, mode 600 |
| Database | `/opt/projectdawn/world.db` (absolute path in `.env`, so it does not depend on CWD) |
| Tailnet address | `100.93.108.112` |
| Unit | `/etc/systemd/system/projectdawn.service`, enabled |
| Firewall | `ufw allow in on tailscale0` for 8765/tcp and 7777/udp |

The clone used `-b <branch>` deliberately, so the deploy cannot silently land on the default
branch again.

The service account needed its own copy of the GitHub deploy key and `~/.ssh/config`, since
the key lived in `wrightt`'s home. Copying rather than minting a second key is fine: it is
already read-only and scoped to one repository.

Clock check passed (`timedatectl`: NTP active, system clock synchronized). That matters more
than it looks: per `deployment_linux.md`, ConnectTokens live 30 s and the **client**
validates them against its own clock, so a drifted server produces a successful login
followed by a world join that hangs.

### A typo in a variable *name* looks exactly like a missing config file

The first service start crash-looped with:

```
Error: loading server config
Caused by:
    PROJECTDAWN_NETCODE_KEY is required.
```

`.env` existed, was owned correctly, and was mode 600. The actual cause was a single
character in the key's **name**: `PROJECTDAWN_NETCLODE_KEY`. The server looked up the
correct name, found nothing, and reported it missing. Entirely accurate, and it points at
the value rather than the spelling.

Useful technique for inspecting a file that holds a secret:

```bash
sudo cut -c1-32 /opt/projectdawn/.env
```

That prints the first 32 characters of every line, so variable names and the shape of each
value are visible while the key itself is not. It is what made the extra `L` obvious.

Also worth noting: `Restart=on-failure` with `RestartSec=5s` means a bad config produces a
crash loop, not a single clear failure. `systemctl stop` first, then diagnose, or the log
fills with restarts faster than it can be read.

---

## Remaining stages

Shape of the road, not yet detailed. Each gets written when its predecessor closes.

- **Stage I.** See the written stage above.
- **Stage J.** Production posture: netcode private key handling for a real host (the
  server refuses to boot without one), `PD_DEV_CMDS` **off**, and `grant_gm` applied to
  the operator account only. See the GM access notes in
  `docs/concepts/architecture/systems_overview.md`.
- **Stage K.** Reachability: host firewall plus router port forwarding for the auth
  WebSocket on 8765 and the UDP world port.
- **Stage L.** Durability: a systemd unit so the server survives reboots, and an off-box
  backup of `world.db`.
- **Stage M.** Client and testers: a client build pointed at the real host, a refreshed
  `README_FOR_TESTERS.md` (it predates roughly ten weeks of work), and confirmation that
  the in-game bug-report button still routes somewhere that gets read.

---

## Definition of done

Per the To-Do item: someone who is not the operator, on a machine that is not the
operator's, makes an account, makes a character, kills something, and logs out clean.

Ticking that To-Do item still requires playtest evidence under the Session workflow gate
in `CLAUDE.md`. A host that serves the operator's own machine is **built**, not **done**.

### Status against that bar, 2026-08-10

| Requirement | State |
|---|---|
| A server exists and stays up | Done. systemd, `enabled`, survives reboot. |
| Reachable from another machine | Done over the tailnet, proven from the dev box. |
| Account, character, kill, clean logout | Done, as a rehearsal by the operator. |
| Persistence across logout | Done. Character and XP intact on re-login. |
| **By someone who is not the operator** | **Not yet.** |
| **From a machine that is not the operator's** | **Not yet.** |

### Before inviting anyone

1. ~~**Backups.**~~ **Done 2026-08-10**, see below.
2. **Refresh `README_FOR_TESTERS.md`.** It predates roughly ten weeks of work and now also
   needs Tailscale onboarding instructions, since a tester cannot connect without joining
   the tailnet first.
3. **Know the accepted gaps** from `deployment_linux.md` §9: no kick, no ban, no shutdown
   warning; the database is not in WAL mode despite comments claiming otherwise; and
   stopping the service drops up to 60 s of state for everyone online because there is no
   SIGTERM handler.

---

## Backups, as configured 2026-08-10

| | |
|---|---|
| Script | `/opt/projectdawn/src/scripts/backup.sh` (uses `sqlite3 .backup`, safe against a live DB) |
| Source | `/opt/projectdawn/world.db` (VD0) |
| Destination | `/data/projectdawn-backups` (VD1) |
| Schedule | `/etc/cron.d/projectdawn-backup`, 04:00 daily, as the `projectdawn` user |
| Retention | 7 days (raise with `PROJECTDAWN_BACKUP_RETAIN=30` in the cron line) |

Backups land on **VD1, a different physical array** from the live database on VD0. That is
deliberate: it survives losing VD0, which is a real risk with 2013-vintage drives.

### Four things that had to be fixed to get here

- **`sqlite3` was not installed.** The Stage I1 prerequisites missed it, and the server
  itself never needs it because it links SQLite in. `sudo apt install -y sqlite3`.
- **`backup.sh` is committed without its executable bit** (`-rw-r--r--`, despite a
  `#!/usr/bin/env bash` shebang), so it fails with `Permission denied`. Fixed locally with
  `chmod +x`; the proper fix is `git update-index --chmod=+x scripts/backup.sh` in the repo,
  **on the dev box**, so future clones get it.
- **`/opt/projectdawn` is mode `750`**, so the operator account cannot read anything under it
  without `sudo`. That is the service isolation working, not a fault.
- **`/etc/cron.d` files take a username column** that personal crontabs do not, and the
  filename must contain **no dots**. Either mistake makes cron ignore the file silently.

### Verify, do not assume

Two separate checks, both worth doing, because they prove different things.

**The backup contains real data**, not just a plausible file of the right size:

```bash
sudo -u projectdawn sqlite3 /data/projectdawn-backups/world-<ts>.db "SELECT COUNT(*) FROM accounts;"
sudo -u projectdawn sqlite3 /data/projectdawn-backups/world-<ts>.db "SELECT name, level FROM characters;"
```

Result on 2026-08-10: `1` account, and `Pockets|2` came back out of the file.

**Cron actually invokes it.** Running the script by hand proves the script; it does not prove
cron's invocation, which has a different environment, a minimal PATH and a different user
context. "The backup job that never ran" is discovered at the worst possible moment.

Temporarily set the schedule to `* * * * *`, wait ~90 s, confirm new files appear in
`/data/projectdawn-backups`, then set it back to `0 4 * * *`. Confirmed working.

### Off-box copy, done 2026-08-10

Both arrays are in one chassis, so the on-box backup survives losing VD0 but not the machine
dying, a fire, or a mistake that removes both.

Closed by a weekly Windows Task Scheduler job on the dev box that `scp`s
`/data/projectdawn-backups/*.db` into a Google Drive folder, which syncs it off-site. Two
problems (automate it, get it out of the building) solved by one job, because copying into a
cloud-synced folder makes the sync do the off-site half.

Details in `server_operations.md`. The world now exists in three places: VD0 live, VD1
nightly, Google Drive weekly.

# udev rules

Custom udev rules I use for X-Plane hardware on Linux. Each file targets specific USB devices by vendor/product ID and adjusts permissions, tagging, and symlinks so X-Plane (and related tools) see the devices correctly — or, in the case of the Keychron keyboards, so the sim doesn't pick them up at all.

All rule files live in `udev/rules.d/` and are intended to be dropped into `/etc/udev/rules.d/`.

## Installation

```sh
sudo cp udev/rules.d/*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Unplug and replug the affected device (or reboot) if it was connected before the rules were loaded.

## 99-winctl.rules — WinWing controllers

Creates stable `/dev/winctrl-*` symlinks to the `hidraw` nodes for a range of WinWing panels and controllers (vendor `4098`), and opens the devices up to `MODE="0666"` so user-space tools can talk to them without root.

Devices covered include: Ursa Minor sticks, MCDU32, PFP3N/PFP4/PFP7 (captain/first officer/observer variants), FCU and EFIS modules, PAP3, ECAM32, AGP, throttles, and PDC units (3M and 3N variants).

The stable symlink is the useful bit — it means tooling and plugin configuration can reference e.g. `/dev/winctrl-fcu` instead of guessing which `hidrawN` the kernel happened to assign this boot.

## 99-cat3-tiller.rules — Cat3Design Airbus Tiller

The Cat3Design Airbus Tiller (vendor `27dc`, product `16c0`) ships with generic/empty USB descriptors, so out of the box Linux doesn't identify it as a joystick and X-Plane won't bind to it cleanly. This file fixes that:

- **USB level** — sets group/permissions and applies `uaccess`/`udev-acl` tags so the logged-in desktop user can access it.
- **HID level** — matches on the HID child so the rule fires once the HID subsystem has attached.
- **Input level (`js*` and `event*` nodes)** — sets the `ID_VENDOR`/`ID_MODEL` metadata to "Cat3Design" / "Airbus_Tiller", forces `ID_INPUT_JOYSTICK=1` so desktop environments and X-Plane tag it as a joystick, and creates stable symlinks at `/dev/input/cat3-tiller` (legacy js API) and `/dev/input/cat3-tiller-event` (evdev).

Without these rules the tiller either fails to show up in X-Plane's joystick list or appears as an unnamed/unknown device.

## 99-keychron.rules — Keychron K10 HE & Keychron Link

Two concerns bundled together for vendor `3434`:

1. **Grant hidraw access** to the keyboards (product `0ea0` for the K10 HE, `d030` for the Keychron Link) so companion software — e.g. keyboard config tools — can talk to them via `hidraw` without root.
2. **Suppress phantom joystick detection.** Both devices expose an input interface that the kernel helpfully tags as a joystick. X-Plane then enumerates the keyboard as a joystick and can end up bound to random key presses as axes or buttons. The fix strips joystick tagging on the `event*` nodes, and on the `js*` nodes it additionally sets `MODE="0000"`, removes `uaccess`/`udev-acl`/`seat` tags, and clears any filesystem ACLs via `setfacl -b`. Net result: the `/dev/input/js*` entry exists but nothing in user space can open it, so X-Plane skips past it silently.

If you add another Keychron model, copy one of the blocks and change the `idProduct` value. The product IDs are findable with `lsusb` or by checking `/sys/class/hidraw/hidraw*/device/uevent`.

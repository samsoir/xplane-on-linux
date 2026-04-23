# sysctl tuning for XEarthLayer

`sysctl.d/99-xearthlayer.conf` contains a set of Linux VM (virtual memory) tunables used to keep X-Plane and the [XEarthLayer](https://xearthlayer.com/) plugin responsive under sustained memory pressure — in particular the large, bursty I/O patterns produced by XEarthLayer's tile cache.

Attribution: the approach and values are based on the case study by **emvisio.com** — see <https://www.emvisio.com/en/linux/system/tuning_casestudy.html>. Credit for the underlying analysis belongs to them; this file simply captures the settings I run on my own system.

## Installation

Copy the file into `/etc/sysctl.d/` and apply:

```sh
sudo cp sysctl.d/99-xearthlayer.conf /etc/sysctl.d/
sudo sysctl --system
```

To verify, read any of the keys back with `sysctl vm.swappiness` (etc.).

## What each setting does

### Memory watermarks

```
vm.min_free_kbytes = 1048576         # 1 GiB
vm.watermark_scale_factor = 500      # 5.0% of memory
```

These control how aggressively the kernel's background reclaim daemon (`kswapd`) starts freeing pages.

- `min_free_kbytes` raises the absolute floor of free memory the kernel tries to maintain. At 1 GiB, kswapd has meaningful headroom to work with before allocations start stalling on direct reclaim.
- `watermark_scale_factor` widens the gap between the low and high watermarks (units of 0.01%, so 500 = 5%). A wider gap means kswapd gets more runway to reclaim in the background, smoothing out allocation latency when XEarthLayer is streaming tiles.

Net effect: fewer allocation stalls in the X-Plane main thread during heavy tile I/O.

### Swap behavior

```
vm.swappiness = 8
```

Controls the kernel's preference for reclaiming anonymous memory (swapping out application pages) vs. evicting file-backed page cache. The default is 60. Lowering it to 8 tells the kernel to strongly prefer dropping cached file pages over swapping out the simulator's working set. Swap is still available for genuine pressure — just not used opportunistically.

### Swap readahead

```
vm.page_cluster = 0
```

When a page is faulted back in from swap, the kernel can read neighbouring pages at the same time. On spinning disks this amortises seek cost; on NVMe and SSDs there is no seek, and the extra pages just consume memory that is already scarce. Setting to 0 disables swap readahead entirely, making swap-in use single-page reads.

### Dirty page limits

```
vm.dirty_background_ratio = 3        # start async writeback at 3% of RAM dirty
vm.dirty_ratio = 10                  # block writers at 10% of RAM dirty
```

These cap how much modified-but-not-yet-flushed data the kernel will accumulate in RAM.

- `dirty_background_ratio` lowered to 3% means the kernel starts flushing dirty pages to disk early and continuously, rather than letting them pile up.
- `dirty_ratio` lowered to 10% is the hard ceiling — once hit, processes writing new data are blocked until flushing catches up.

This matters when XEarthLayer's tile cache lives on a SATA SSD (or any storage slower than NVMe): if dirty pages are allowed to grow to the defaults (typically 10% / 20%), the eventual flush can stall the sim for seconds at a time. Tighter limits trade a small amount of sustained write activity for much smoother latency.

## Reverting

Remove the file and re-apply:

```sh
sudo rm /etc/sysctl.d/99-xearthlayer.conf
sudo sysctl --system
```

The kernel will fall back to whatever values the distribution ships.

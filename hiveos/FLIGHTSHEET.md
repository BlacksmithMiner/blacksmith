# BLACKSMITH — HiveOS Flight Sheet

Everything you need to run BLACKSMITH on HiveOS. Two ways to install the miner, then one Flight Sheet.

## 1. Install the custom miner

**Option A — Installation URL (easiest).** In the Flight Sheet's *Setup Miner Config* there is an
**Installation URL** field. Paste this and HiveOS pulls the package itself:

```
https://github.com/BlacksmithMiner/blacksmith/releases/download/v1.0.0/blacksmith-hiveos-1.0.0.tar.gz
```

**Option B — manual.** Download `blacksmith-hiveos-1.0.0.tar.gz` from the
[Releases](https://github.com/BlacksmithMiner/blacksmith/releases) page and, on the rig:

```bash
cd /hive/miners/custom && tar xzf blacksmith-hiveos-1.0.0.tar.gz
```

The package name is **blacksmith-hiveos** (`CUSTOM_NAME=blacksmith-hiveos`). On first run the package
auto-provisions the rig for the GPU(s) it detects:

* it reads every card (`nvidia-smi`), and if the **NVIDIA driver** is missing or too old for CUDA 13
  it installs a suitable one automatically via HiveOS's own `nvidia-driver-update` (the rig reboots
  once when that finishes — set `FORGE_DRIVER_AUTO=0` to only print the command instead), and
* it fetches the CUDA 13 runtime (`libcublasLt.so.13`) once into a persistent cache that survives
  HiveOS updates, so a new package version never re-downloads it.

## 2. Create the Flight Sheet

*Wallets → add a BTX wallet*, then *Flight Sheets → create*:

| Field                          | Value                                                                        |
|--------------------------------|------------------------------------------------------------------------------|
| **Coin**                       | `BTX` (or *Custom* if BTX isn't listed)                                       |
| **Wallet**                     | your **BTX payout address** (`btx1…`), optionally `btx1….%WORKER_NAME%`       |
| **Pool**                       | *Configure in miner*                                                          |
| **Miner**                      | **Custom** → select **blacksmith-hiveos**                                            |

Then open **Setup Miner Config** on the miner and fill:

| Miner-config field             | Value                                                                        |
|--------------------------------|------------------------------------------------------------------------------|
| **Installation URL**           | `https://github.com/BlacksmithMiner/blacksmith/releases/download/v1.0.0/blacksmith-hiveos-1.0.0.tar.gz` |
| **Hash algorithm**             | leave empty / `btx`                                                          |
| **Wallet and worker template** | `%WAL%.%WORKER_NAME%`                                                        |
| **Pool URL**                   | `btx-eu.lproute.com:8666` (or another region: `btx-au`, `btx-pl`, … `.lproute.com:8666`) |
| **Pass**                       | `x`                                                                          |
| **Extra config arguments**     | *(optional)* e.g. a second `--stratum` for failover                          |

Apply the Flight Sheet. The rig pulls the CUDA runtime on the first run, then mining starts; the
HiveOS dashboard shows live **ep/s** (= H/s the pool credits) and accepted/rejected shares within a
minute (the package forces `--ui json` so the dashboard can read the stats).

## Notes

* **Port `8666`, not `8665`.** LuckyPool's self-signed certificate and the port are handled for you —
  no extra flags.
* `%WAL%` is your BTX payout address; `%WORKER_NAME%` becomes the worker label so each rig reports
  itself separately.
* Driver requirement: **NVIDIA ≥ 580** (CUDA 13). Cards: RTX 30 / 40 / 50 (sm_86 / 89 / 120). The
  package installs/updates the driver for you when it's inadequate; disable with `FORGE_DRIVER_AUTO=0`.
* 3% disclosed devfee (see the main README).

Support: [blacksmith.best](https://blacksmith.best) · [Discord](https://discord.gg/kcjUZ4Raz)

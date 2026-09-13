<h1 align="center">BLACKSMITH — the fastest BTX GPU miner</h1>

<p align="center">
  A CUDA miner for <b>BTX</b> (MatMul&nbsp;v4.7 / ENC_RC proof-of-work) for NVIDIA GPUs.<br>
  Linux &amp; HiveOS. One command to start, and a ready HiveOS Flight&nbsp;Sheet.
</p>

<p align="center">
  🌐 <a href="https://blacksmith.best">blacksmith.best</a> &nbsp;·&nbsp;
  💬 <a href="https://discord.gg/kcjUZ4Raz">Discord</a>
</p>

```
  ██████╗ ██╗      █████╗  ██████╗██╗  ██╗███████╗███╗   ███╗██╗████████╗██╗  ██╗
  ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██╔════╝████╗ ████║██║╚══██╔══╝██║  ██║
  ██████╔╝██║     ███████║██║     █████╔╝ ███████╗██╔████╔██║██║   ██║   ███████║
  ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ ╚════██║██║╚██╔╝██║██║   ██║   ██╔══██║
  ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗███████║██║ ╚═╝ ██║██║   ██║   ██║  ██║
  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝
```

## Download

Grab the latest build from the [**Releases**](https://github.com/BlacksmithMiner/blacksmith/releases) page:

* `BLACKSMITH-<version>-linux-x86_64.tar.gz` — the miner for any Linux box.
* `blacksmith-hiveos-<version>.tar.gz` — the HiveOS custom-miner package.

## Requirements

* An **NVIDIA GPU** — RTX 20/30/40/50, A100, H100 (compute capability 8.0–12.0).
* The **NVIDIA driver ≥ 580** (that is what CUDA 13 needs). Check with `nvidia-smi`.
* The **CUDA 13 runtime** (`libcublasLt.so.13`). You do **not** have to install the whole CUDA
  toolkit — the miner fetches just this one library for you on first run, or tells you the exact
  command if it can't. See below.

## Quick start — Linux / Ubuntu

```bash
tar xzf BLACKSMITH-*-linux-x86_64.tar.gz && cd BLACKSMITH-*-linux-x86_64
./blacksmith --user <YOUR_BTX_WALLET>.<worker> --pass x
```

`./blacksmith` is a small launcher. Before starting the miner it auto-provisions the host for the
GPU(s) it detects:

1. checks your NVIDIA driver — if it's missing or too old for CUDA 13 and you run as root, it installs
   a suitable one for you (`ubuntu-drivers install`, or `nvidia-driver-580`); otherwise it prints the
   exact command. Reboot once after a driver install. Disable with `FORGE_DRIVER_AUTO=0`.
2. makes sure the CUDA 13 runtime (`libcublasLt.so.13`) is present — if it isn't, it downloads just
   that library for you (once, cached), and if it can't reach the internet it prints **exactly what
   to install and from where** instead of a cryptic loader error.

Then it launches the miner with your arguments. You can also run the binary directly:
`./blacksmith-forge --user … --pass x`.

### Which pool?

**LuckyPool** works out of the box — just point `--user` at your BTX payout address:

```bash
./blacksmith --user btx1yourwallet.rig1 --pass x
```

The default pool is `stratum+tls://btx-eu.lproute.com:8665` — LuckyPool's native **AEK1** protocol,
which validates each share by re-running the episode itself (ExactReplay), so accepted shares are
credited immediately and honestly. Pick a closer region if you like (`btx-us-east`, `btx-us-west`,
`btx-us-central`, `btx-us-ord`, … `.lproute.com:8665`) with `--stratum`. TLS and LuckyPool's
self-signed certificate are handled for you — no extra flags. The part before the dot in `--user`
is your payout address; the part after the dot is an optional worker label.

Full option list: `./blacksmith-forge --help`.

## Multi-GPU / whole rig

`./blacksmith-rig` runs the miner across every GPU in the box (or a chosen subset) as one command:

```bash
./blacksmith-rig --user btx1yourwallet.rig1 --pass x
# or a specific subset:
./blacksmith-rig --user btx1yourwallet.rig1 --gpu-devices 0,1,2,3 -- --stall-timeout 600
```

Each GPU still runs its own fully independent `blacksmith-forge` process (own attest, own CUDA
context) — a crash or hang on one card never touches the others, and the supervisor restarts only
the card that died. Worker names sent to the pool are `<rig-label>_gpu<index>` automatically.

Check on it any time, from any SSH session (it only reads log files, never touches the miners):

```bash
./blacksmith-rig-status                 # one-shot table: GPU / speed / shares / status
./blacksmith-rig-status --watch         # live-refreshing view
```

## HiveOS

The HiveOS package (`blacksmith-hiveos-<version>.tar.gz`, or the `hiveos/blacksmith-hiveos/` folder here) is a ready
custom miner. It installs the miner, fetches the CUDA 13 runtime once into a persistent cache
(survives updates), reports live hashrate and accepted/rejected shares to the dashboard, and
restarts cleanly.

**→ Full step-by-step Flight Sheet guide: [`hiveos/FLIGHTSHEET.md`](hiveos/FLIGHTSHEET.md).**

**Install (once):** in the Flight Sheet's *Setup Miner Config* set the **Installation URL** to
`https://github.com/BlacksmithMiner/blacksmith/releases/latest/download/blacksmith-hiveos-1.2.tar.gz`
(HiveOS pulls it itself), or upload the package in HiveOS → *Miners → Custom → Install*, or drop the
folder into `/hive/miners/custom/blacksmith-hiveos/`.

**Flight Sheet** (Wallet and Worker Template → Pool → Miner):

| Field                         | What to put                                                                 |
|-------------------------------|-----------------------------------------------------------------------------|
| **Coin**                      | BTX (or any / custom)                                                        |
| **Wallet**                    | your **BTX payout address** (`btx1…`)                                        |
| **Pool URL** (`%URL%`)        | `btx-eu.lproute.com:8665` (or another `btx-<region>.lproute.com:8665`)       |
| **Miner**                     | Custom → **blacksmith-hiveos**                                                          |
| **Miner config / Setup Miner Config** | leave defaults; the package forces `--ui json` so the dashboard can read stats |
| **Pass**                      | `x` (default)                                                                |
| **Extra config arguments**    | optional extra flags, e.g. a second `--stratum` for failover                 |

In the Wallet and Worker template put your BTX address, optionally as `address.%WORKER_NAME%` so
each rig reports its own worker name. Apply the Flight Sheet — the first run pulls the CUDA runtime
and then mining starts; the dashboard shows H/s and accepted shares within a minute.

## Speed

BTX hashrate is measured in **ep/s** (episodes per second) — one episode is one hash, there is no
megahash conversion. `ep/s` is exactly the `H/s` the pool credits. BLACKSMITH is tuned to be the fastest
BTX miner available; on a given card it runs at the GPU's power limit.

## Devfee

This build mines a fixed **3%** of its runtime to the developer: the first 2 minutes after every
start, then 2 minutes at the start of every hour of the run's own uptime. Restarting cannot skip it.
Everything else is yours.

## Support

* Site: **[blacksmith.best](https://blacksmith.best)**
* Discord: **[discord.gg/kcjUZ4Raz](https://discord.gg/kcjUZ4Raz)**

If the miner ever stops with a `CRITICAL ERROR`, jump into Discord — the current invite is always
linked from the site if the one above has expired.

## License

Proprietary — distributed by the BlacksmithMiner team. The vendored GPU-episode code it builds on is
third-party MIT (its notice travels inside every release archive). See the release archive for the
full notices.

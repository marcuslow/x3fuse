# X3Fuse — dual-illuminant DNGs for Sigma Foveon cameras

**An unofficial build of [X3Fuse](https://github.com/sagwaco/x3fuse) that converts Sigma Merrill and Quattro X3F files into DNGs carrying two camera colour profiles instead of one — so raw editors that read both, above all Apple Photos, reproduce Foveon colour correctly under any light, and keep it correct when you move the white-balance slider.**

X3Fuse itself is the work of [Sang Lee (mangosango)](https://github.com/mangosango) at [sagwaco](https://github.com/sagwaco): the macOS app, the [x3fuse-core](https://github.com/sagwaco/x3fuse-core) Rust converter it embeds, and the DNG-compatibility work that makes Foveon files open in Adobe, LibRaw and Apple RAW engines at all. This fork adds a colour-science layer on top and fixes a few things found along the way. If you don't need what's described below, use the [official release](https://github.com/sagwaco/x3fuse/releases).

![X3Fuse logo and app screenshot](app-screenshot.png)

> [!IMPORTANT]
> **Download:** [latest release](https://github.com/marcuslow/x3fuse/releases/latest) · **Apple Silicon only** · locally signed, not notarized (see [Installation](#installation)) · **Capture One users: stay on [fix.2](https://github.com/marcuslow/x3fuse/releases/tag/v0.1.5-dp2q-fix.2)** (see [Editor support](#editor-support))

## Why two profiles

A DNG tells the raw editor how the sensor's three channels map to real colour through a `ColorMatrix`. That mapping is not fixed — it depends on the light the scene was lit by, because the sensor's spectral response and the illuminant's spectrum interact. A matrix measured under daylight is slightly wrong under tungsten, and vice versa. Foveon sensors, with their three stacked silicon layers and heavily overlapping spectral responses, are more sensitive to this than Bayer sensors.

A single-profile DNG carries one matrix, measured at one illuminant. White balance is then just three per-channel gains laid on top. Gains can make a grey card come out grey under any light, but they cannot repair the *hue* errors of using the wrong matrix: saturated reds drift orange, skin loses its hue, deep blues shift. The further the actual light is from the calibration illuminant — and the further you drag the white-balance slider from as-shot — the larger the error.

The DNG specification solves this with **dual-illuminant profiles**: two matrices, one for CIE Standard Illuminant A (tungsten, 2856 K) and one for D65 (daylight, 6504 K). The editor estimates the scene's colour temperature and blends the two, so colour stays correct across the whole range. Every Adobe-made camera profile works this way. Most X3F converters write one matrix.

Sigma's Quattro cameras already record what's needed. The CAMF metadata in every Quattro X3F carries a colour-correction matrix and a gain triplet for each white-balance preset, including the body's own tungsten (`Incandescent`) and daylight (`Overcast`) calibrations. This build reads both, adapts them into the DNG's XYZ frame (Sigma's matrices are D65-referenced by construction, so each anchor is one Bradford step away) and writes:

| DNG tag | source | illuminant |
|---|---|---|
| `ColorMatrix1` / `ForwardMatrix1` | Overcast calibration | D65 (21) |
| `ColorMatrix2` / `ForwardMatrix2` | Incandescent calibration | Standard A (17) |

Both matrices are verified against the camera's own numbers on every conversion: each `ColorMatrix` maps its illuminant's white onto the camera-native neutral that preset produces, and both `ForwardMatrix` tags land on D50. On a daylight shot the as-shot rendering is identical to the single-profile build — the difference appears under tungsten, in mixed light, and whenever you touch the white-balance slider.

Dual profiles are written for Quattro-generation files. Merrill files keep the single matrix from upstream, whose calibration has not been validated in this frame.

## Editor support

Writing two matrices only helps if the editor reads them, and here the editors differ sharply. Tested on a 79-frame SIGMA dp2 Quattro shoot (manual 5200 K white balance):

| editor | reads both matrices | white-balance slider | verdict |
|---|---|---|---|
| **Apple Photos** — also Preview, Quick Look, Pixelmator, Photomator (Apple RAW engine) | yes | moves smoothly warm ↔ cool around as-shot | **recommended** |
| **Adobe Lightroom / Camera Raw** | yes (dual-illuminant is Adobe's own design) | expected to behave as with any Adobe profile | not yet tested by this fork |
| **RawTherapee** | yes, via its DCP path | — | untested |
| **darktable** | one matrix only | — | untested; dual is harmless but brings nothing |
| **Luminar Neo** | appears to use one matrix | over-blues and over-warms towards the ends, in our use | not measured |
| **Capture One 15.3** | **no** | files import as "Custom" white balance; the Kelvin slider goes blue in both directions | **use fix.2** |

### Why Apple Photos handles these files so well

Apple's RAW engine is a faithful DNG reader. It honours `CalibrationIlluminant1/2` and blends both `ColorMatrix` tags by estimated colour temperature; it uses the `ForwardMatrix` path with proper chromatic adaptation to D50; and its white-balance slider is a *colour temperature*, computed through the camera profile along the illuminant locus, rather than a direct scaling of raw channel gains. The result is that a Foveon DNG from this build behaves in Photos exactly like a native raw from a well-profiled camera: warm light renders warm rather than orange, cool light renders cool rather than cyan, and the extremes of the slider are still plausible lights. In our tests both illuminant orderings render identically, and a white-balance sweep across all seven of the camera's presets tracked the expected direction every time.

Capture One is the notable exception. It initialises a DNG's white balance from `CalibrationIlluminant1` as if the picture had been taken under that light — correct for single-matrix files, whose writers set the tag to the shooting illuminant — and its Kelvin model breaks with a second matrix present, in either order. Until that changes, Capture One users should use [fix.2](https://github.com/marcuslow/x3fuse/releases/tag/v0.1.5-dp2q-fix.2), which writes the single-matrix DNGs Capture One handles well; a single-matrix option for this build is planned.

## Also fixed in this fork

- **Manual colour-temperature white balance on Quattro bodies.** Files shot with a Kelvin white balance (CAMF `WhiteBalance` code 11, `ColorTemp`) failed to convert upstream. The camera's `ColorTempTableInfo` is interpolated at `ColorTempValue`, and its gain pair is mapped into the preset gain frame — the table and the presets are normalised differently, and reading the pair naively produces a green cast. Proposed upstream as [x3fuse-core PR #14](https://github.com/sagwaco/x3fuse-core/pull/14).
- **Convert converts the whole queue.** After dragging several files in, macOS auto-selects one row and upstream converted only that file. Proposed upstream as [x3fuse PR #43](https://github.com/sagwaco/x3fuse/pull/43).
- **DNG thumbnails that look like the photo.** Finder, Quick Look, Photos and Lightroom show a DNG's embedded preview at thumbnail sizes. Upstream embeds a 300 px preview rendered from the linear raw data without a profile or tone curve (flat colours, magenta skies). Since fix.10 the preview is the camera's own embedded JPEG, downscaled to 1600 px and stored as a JPEG-compressed DNG preview, the layout Adobe's DNG Converter uses. The raw data is unchanged. Fixed in the fork's [x3fuse-core](https://github.com/marcuslow/x3fuse-core) (`2a27f1c`).

## Installation

### Requirements

- macOS 14.0 (Sonoma) or later
- **Apple Silicon.** The converter embedded in current fork releases is arm64 only. Intel Macs: use [fix.2](https://github.com/marcuslow/x3fuse/releases/tag/v0.1.5-dp2q-fix.2), which is universal, or the [official release](https://github.com/sagwaco/x3fuse/releases).

### Steps

1. Download the `.zip` from the [latest release](https://github.com/marcuslow/x3fuse/releases/latest) and check its SHA-256 against the one in the release notes.
2. Extract it and move `X3Fuse.app` to your Applications folder.
3. Launch it. The app is locally (ad-hoc) signed rather than notarized with the upstream developer's Apple certificate, so macOS may block it the first time: Control-click `X3Fuse.app` and choose **Open**. If it is still blocked, and only after verifying the checksum, remove quarantine from this app alone:

   ```bash
   xattr -dr com.apple.quarantine /Applications/X3Fuse.app
   ```

The app's built-in updater points at the upstream project's feed, so it will not announce new fork releases; check the [Releases page](https://github.com/marcuslow/x3fuse/releases). The upstream Homebrew cask (`sagwaco/tap/x3fuse`) installs the official build, not this one.

## Usage

1. Launch X3Fuse.
2. Drag X3F files onto the window, or use File → Open.
3. Choose DNG as the output format (dual-illuminant profiles apply to DNG only; TIFF and JPEG are rendered with the as-shot white balance) and set an output folder.
4. Click **Convert**. The whole queue is processed.
5. Import the DNGs into Apple Photos — or any editor in the table above — and use the white-balance slider freely.

### Convert from Finder

Since fix.9 the app can be driven from Finder without opening it first:

- **Quick Action.** Right-click one or more `.X3F` files (or a folder of them) and choose **Quick Actions → Convert to DNG with X3Fuse**. The installed app opens, queues the files and converts them immediately with your current settings. Files already in the queue are reused, requests that arrive during another conversion wait their turn, and existing output for the chosen files is overwritten without the usual dialog. The Quick Action is an Automator workflow in [`Finder/`](Finder/); install it once with

  ```bash
  ./scripts/install_quick_action.sh
  ```

  or double-click `Finder/Convert to DNG with X3Fuse.workflow` and click **Install**. If it does not show up, enable it under System Settings → General → Login Items & Extensions → Extensions → Finder. It talks to `/Applications/X3Fuse.app` (falling back to whichever X3Fuse Launch Services knows), so keep the app there.
- **Open With / Dock.** `.X3F` files can be opened with X3Fuse from Finder's Open With menu, dropped on its Dock icon, or passed with `open -a X3Fuse file.X3F`. These only add the files to the queue; press **Convert** as usual.
- **URL scheme.** `x3fuse://convert?format=dng&path=<percent-encoded path>&path=…` queues and converts; `x3fuse://open?path=…` only queues. `format` accepts `dng`, `tiff` or `jpg` and applies to that conversion only, overriding the settings and the "Extract JPG only" checkbox (since fix.11; fix.9 and fix.10 let the checkbox win).

## Supported cameras

Inherited from upstream. Dual-illuminant profiles apply to the Quattro generation; the fork's colour work has been verified on the dp2 Quattro and is expected to carry over to the other Quattro bodies, which store the same CAMF calibration data.

| Camera model | status |
| --- | --- |
| Sigma DP1 / DP2 / DP3 Merrill, SD1 Merrill | supported upstream; single profile |
| Sigma DP0 / DP1 / DP2 / DP3 Quattro | dual profile; **dp2 Quattro verified** |
| Sigma SD Quattro, SD Quattro H | dual profile; untested by this fork |

X3I files (Quattro Super Fine Detail mode) are not supported, as upstream. Shoot exposure-bracketed X3Fs and merge the DNGs in your editor instead.

## Building from source

```bash
git clone https://github.com/marcuslow/x3fuse.git
cd x3fuse
open X3Fuse.xcodeproj      # Product → Run
```

The Xcode project embeds the checked-in `X3Fuse/x3f_extract`. To rebuild it from the converter source, clone [marcuslow/x3fuse-core](https://github.com/marcuslow/x3fuse-core) next to this repository, check out the `feat/dual-illuminant-profiles` branch, and run `./scripts/build_x3f_extract.sh` — it needs `rustup` with both Apple targets installed to produce a universal binary. The converter also builds and runs on its own:

```bash
x3f_extract -dng <file.X3F>                          # dual-illuminant (default)
x3f_extract -dng -dng-single-illuminant <file.X3F>   # legacy single matrix, for comparison
```

To inspect what a DNG carries, note that plain `exiftool -ColorMatrix1` reports the embedded side-profiles' matrix rather than the main one; use `exiftool -a -G1 -IFD0:ColorMatrix1 -IFD0:ColorMatrix2 -IFD0:CalibrationIlluminant1 -IFD0:CalibrationIlluminant2 file.dng`.

## Relationship to upstream

This is a personal fork maintained for Apple Photos users of Sigma Quattro cameras. Fixes that belong upstream are submitted there ([x3fuse-core #14](https://github.com/sagwaco/x3fuse-core/pull/14), [x3fuse #43](https://github.com/sagwaco/x3fuse/pull/43), [x3fuse #45](https://github.com/sagwaco/x3fuse/pull/45)); the dual-illuminant work is kept here until the editor-support picture — Capture One in particular — is clearer. Issues about the dual-illuminant profiles or these releases belong on [this fork's issue tracker](https://github.com/marcuslow/x3fuse/issues); everything else belongs [upstream](https://github.com/sagwaco/x3fuse/issues).

## Acknowledgements

- [**X3Fuse**](https://github.com/sagwaco/x3fuse) and [**x3fuse-core**](https://github.com/sagwaco/x3fuse-core) by [Sang Lee (mangosango)](https://github.com/mangosango) / [sagwaco](https://github.com/sagwaco) — the app, the Rust converter, and the DNG-compatibility groundwork this fork builds on.
- [**x3f_tools**](https://github.com/Kalpanika/x3f) by Kalpanika, the original C/C++ Foveon converter that x3fuse-core ports. This project is not affiliated with nor endorsed by its creators.
- [**ExifTool**](https://github.com/exiftool/exiftool) for metadata handling, and [**Sparkle**](https://sparkle-project.org) for the update framework.

## License

X3Fuse is licensed under the [GNU General Public License v3.0](LICENSE), as upstream. x3fuse-core is licensed under Apache-2.0.

This project is not affiliated with nor endorsed by Sigma Corporation. Sigma and Foveon are trademarks of Sigma Corporation.

## Privacy

X3Fuse processes all files locally on your Mac. No data is sent to external servers.

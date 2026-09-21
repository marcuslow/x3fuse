# 0.1.5-dp2q-fix.13 - Unofficial Preview Scope

- The camera-JPEG DNG preview introduced in fix.10 is now used only for DP1X, DP2X and SD15 files. It was added because those bodies' thumbnails looked flat and magenta, which turned out to be a symptom of their white-balance gains, fixed in fix.12. Quattro, Merrill, DP2 and DP1S DNGs go back to the converter's own rendered preview, as in fix.9 and upstream. Raw data and colour tags are unchanged for every camera.
- Updated embedded converter (x3fuse-core `cc2d705`, arm64). Includes everything from fix.12 and earlier. Apple Silicon only. Locally signed, not an official notarized upstream release.

# 0.1.5-dp2q-fix.12 - Unofficial DP1X / DP2X / SD15 Colour Fix

- No more green DP1X, DP2X and SD15 conversions. Taken literally, these 2010-11 bodies' stored white-balance gains leave the image about 7 percent short of red, and their colour matrices are extreme enough to turn that small error into a heavy green cast in every DNG reader (Apple Photos, Capture One, Lightroom) and in the app's TIFF and JPEG output. The camera's own JPEG and Adobe's native X3F support render the same files correctly. The converter now applies a per-model gain correction (DP2X 1.068 / 1 / 1.010, DP1X 1.091 / 1 / 1.005, SD15 1.082 / 1 / 1.022) fitted against Adobe DNG Converter output on 71 files. On held-out files the as-shot neutral now matches Adobe's within half a percent on average, and a grey object in a DP2X frame renders within half a percent of the camera JPEG. DP2, DP1S, Merrill and Quattro bodies are unchanged.
- Known limitation: the fit covers Auto white balance, which is 94 percent of the tested library. Shots taken with the **Flash** preset under tungsten light, and the rare Incandescent or Daylight preset shots, still render green on these bodies; the problem there is deeper than the gains and is being looked at separately.
- Existing DNGs from these cameras keep the old colour until reconverted; the raw data is unchanged, only the colour tags differ, so reconverting is safe.
- Updated embedded converter (x3fuse-core `e286256`, arm64). Includes everything from fix.11 and earlier. Apple Silicon only. Locally signed, not an official notarized upstream release.

# 0.1.5-dp2q-fix.11 - Unofficial Quick Action Always Makes DNGs

- The Finder Quick Action "Convert to DNG with X3Fuse" now produces a DNG even while the app's "Extract JPG only" checkbox is ticked. In fix.9 and fix.10 the checkbox silently won, so the right-click produced another copy of the embedded JPEG and the old DNG (with its flat preview) stayed on disk. The override applies only to the files in that request; the checkbox and per-file settings behave as before for the Convert button.
- Includes everything from fix.10 (camera-JPEG DNG previews), fix.9 (Finder integration), fix.8, fix.7, fix.6, fix.4 and fix.2. Converter unchanged from fix.10 (x3fuse-core `2a27f1c`, arm64).
- Apple Silicon only. Locally signed, not an official notarized upstream release.

# 0.1.5-dp2q-fix.10 - Unofficial Camera-JPEG DNG Preview

- DNG thumbnails now look like the picture. Finder, Quick Look, Photos and Lightroom show a DNG's embedded preview at thumbnail sizes instead of rendering the raw data, and the converter used to embed a 300-pixel preview rendered from the linear raw data with no camera profile or tone curve: flat colours, magenta skies. The preview is now the camera's own embedded JPEG, downscaled to at most 1600 pixels on the long edge and stored as a standard JPEG-compressed DNG preview, the same layout Adobe's DNG Converter writes. Files grow by well under 100 KB. The raw data and colour profiles are unchanged, so edits and renders in Photos and other editors are identical to fix.9.
- Updated embedded converter (x3fuse-core `2a27f1c`, arm64). Everything from fix.9 (Finder Quick Action, Open With, `x3fuse://` scheme), fix.8, fix.7, fix.6, fix.4 and fix.2 is included.
- Apple Silicon only: the embedded converter is arm64. Intel Macs should use fix.2.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5-dp2q-fix.9 - Unofficial Finder Quick Action

- Convert from Finder. Right-click one or more X3F files (or a folder of them) and choose Quick Actions → **Convert to DNG with X3Fuse**. The installed app opens, adds the files to its queue and starts converting them at once with your current settings (output folder, compression, denoise); DNG is requested per file. Files already in the queue are reused, not duplicated, and requests that arrive while another conversion is running wait their turn. Existing output for the chosen files is overwritten without the usual dialog, because the Quick Action is an explicit per-file request. The Quick Action is a small Automator workflow in the repository under `Finder/`; install it once with `./scripts/install_quick_action.sh` (or double-click the `.workflow` and click Install). If the app's "Extract JPG only" checkbox is ticked, it still wins and the Quick Action extracts JPEGs.
- The app now registers the `x3fuse://` URL scheme (`x3fuse://convert?format=dng&path=…` converts, `x3fuse://open?path=…` only queues) and declares the X3F document type, so Finder offers **Open With → X3Fuse**, dropping X3F files on the Dock icon works, and `open -a X3Fuse file.X3F` adds them to the queue. Those routes only queue; you still press Convert.
- Includes everything from fix.8 (large-batch descriptor fix), fix.7 (Extract JPG only), fix.6 (truncated-file guard, Skip Existing), fix.4 and fix.2.
- Apple Silicon only: the embedded converter in this build is arm64 (unchanged since fix.4). Intel Macs should use fix.2.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5-dp2q-fix.8 - Unofficial Large-Batch Fix

- Large queues no longer collapse near the end. Every converted file leaked four pipe file descriptors (two subprocesses, two pipes each) because the batch loop never pauses and the handles were only released when the whole batch finished. After roughly 2,000 files the app hit its open-file limit and marked every remaining file failed within a fraction of a second, with nothing written to error.log because the logger could not open the log either. The pipes are now closed as soon as each exiftool or x3f_extract run ends, so queues of any size run to completion. Files marked failed this way were never touched; re-convert them.
- Includes everything from fix.7 (Extract JPG only), fix.6 (truncated-file guard, Skip Existing), fix.4 and fix.2.
- Apple Silicon only: the embedded converter in this build is arm64 (unchanged since fix.4). Intel Macs should use fix.2.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5-dp2q-fix.7 - Unofficial Extract JPG Only

- New "Extract JPG only" checkbox beside the Convert button. When checked, Convert copies the camera's embedded JPEG out of each X3F instead of producing a DNG, whatever output format is chosen in Settings or per file. The JPEG is the camera's own full-resolution rendering, extracted byte for byte with its EXIF intact, saved next to the source as `name.X3F.jpg`. The setting is remembered between launches.
- The "Overwrite Existing Files?" dialog now detects existing JPEG and TIFF output as well as DNG, so Skip Existing works for every format.
- Includes everything from fix.6 (truncated-file guard, Skip Existing), fix.4 and fix.2.
- Apple Silicon only: the embedded converter in this build is arm64. Intel Macs should use fix.2.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5-dp2q-fix.6 - Unofficial Truncated-File Guard and Skip Existing

- Truncated or partially copied X3F files are rejected before conversion instead of hanging the queue. x3f_extract spins forever on a file whose header is intact but whose trailing directory offset points past the end of the file; the app now checks the file structure first and marks such files failed with a "re-copy from the camera" message while the rest of the queue continues. Proposed upstream as x3fuse #45.
- The "Overwrite Existing Files?" dialog has a new Skip Existing button that converts only the files without output on disk and leaves existing DNGs untouched.
- That dialog now also appears when freshly added files already have output from a previous run, for every way of starting a conversion (Convert button, Conversion menu / ⌘R, context menu, Convert Selected). Previously it only covered files converted earlier in the same session, so re-adding a folder silently overwrote every DNG.
- Includes everything from fix.4 (dual-illuminant Quattro profiles, ColorTemp white-balance frame fix) and fix.2.
- The existing-output check looks for `name.dng`; TIFF and JPEG outputs are not detected yet.
- Apple Silicon only: the embedded converter in this build is arm64. Intel Macs should use fix.2.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5-dp2q-fix.4 - Unofficial Dual-Illuminant DNG Profiles

- Quattro DNGs now carry dual-illuminant camera profiles: ColorMatrix1/ForwardMatrix1 from the camera's Overcast calibration (D65) and ColorMatrix2/ForwardMatrix2 from its Incandescent calibration (CIE Standard Illuminant A). Readers that support both matrices — Apple Photos, Preview and Quick Look (Apple RAW), Adobe Lightroom and Camera Raw — blend them by scene colour temperature, so colours stay accurate under tungsten and mixed light and when the white-balance slider moves away from as-shot. On daylight shots the as-shot rendering is unchanged.
- Capture One 15.3 does not handle two-matrix DNGs: files import with a "Custom" white balance and the Kelvin slider misbehaves regardless of the illuminant order. If you use Capture One, stay on fix.2 for now; a single-matrix option for this build is planned.
- Manual colour-temperature (ColorTemp) white balance is mapped into the camera's preset gain frame, fixing the green cast in the first version of the upstream fix (x3fuse-core PR #14, `291c2eb`).
- Apple Silicon only: the embedded converter in this build is arm64. Intel Macs should use fix.2.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5-dp2q-fix.3 - Unofficial Dual-Illuminant DNG Profiles

- Write dual-illuminant camera profiles for Quattro DNGs: ColorMatrix1/ForwardMatrix1 from the camera's Incandescent calibration (CIE Standard Illuminant A) and ColorMatrix2/ForwardMatrix2 from its Overcast calibration (D65), so raw converters interpolate the camera's own matrices by scene colour temperature instead of reusing one daylight matrix. Source: x3fuse-core branch `feat/dual-illuminant-profiles`.
- Correct the manual colour-temperature white-balance frame: ColorTemp gains are normalised into the preset gain frame (a 5200 K shot now lands on the Sunlight preset), fixing the green cast in the proposed upstream fix (x3fuse-core PR #14).
- Test build: the embedded converter is Apple Silicon (arm64) only; the app bundle itself remains universal.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5-dp2q-fix.2 - Unofficial DP2Q and Batch Fixes

- Fix DNG conversion for DP Quattro files shot with manual color-temperature white balance by interpolating the camera's embedded gain and color-matrix table.
- Fix the main Convert button processing only one automatically selected row after multiple files are dragged into the queue; it now always converts the full queue.
- Keep conversion native and multicore on Apple Silicon; the universal converter runs arm64 directly and parallelizes decoding, preprocessing, and denoising across available cores.
- This build is locally signed and is not an official notarized release from the upstream X3Fuse project.

# 0.1.5 - Beta 1.1.5

- Update the core converter to x3fuse-core 0.1.2, improving compatibility of converted DNGs (including compressed DNGs) with software powered by Apple RAW and LibRaw, and improving Capture One compatibility for Merrill-generation files.
- Fix highlights clipping prematurely near white on some files, caused by DigitalISOGain scaling during preprocessing.
- Add Spanish (es) localization.
- Fix the denoise slider labels in Settings showing raw localization keys instead of translated text.
- The in-app update prompt now displays release notes, so you can see what changed before updating.

# 0.1.4 - Beta 1.1.4

- The app is now notarized by Apple, so it launches without Gatekeeper warnings, and is installable via Homebrew with `brew install --cask sagwaco/tap/x3fuse`. No functional changes from 0.1.3.
- Packaging-only release; see 0.1.3 for the latest features.

# 0.1.3 - Beta 1.1.3

- Add a denoise slider to control denoising intensity. The maximum value matches the previous default, the minimum is 1, and denoising can be toggled off entirely to disable it.

# 0.1.2 - Beta 1.1.2

- Add highlight recovery option for Merrill DNGs, which prevents string hue shifts in extremely overexposed areas. This setting has only been tested to work with Adobe Camera RAW and LibRaw.
- Add option to apply a flat cineon-like tone curve to tiffs.

# 0.1.1 - Beta 1.1.1

- Make RAW compression warning message easier on the eyes
- Actually supports Intel Macs now...

# 0.1.0 - Beta 1.1.0

- Support Intel Macs. Intel and Apple Silicon macs on macOS 14+ are now supported.
- Apply DPXM green cast fixes to the SD1M
- Add warning message for RAW compression

# 0.0.6 - Beta 1.0.6

- Fix purple tint issue on low ISO SD Quattro H images

# 0.0.5 - Beta 1.0.3

- Improved settings UI
- Add Chinese localizations

# 0.0.4 - Beta 1.0.2

- Test version bump

# 0.0.3 - Beta 1.0.1

- Test version bump

# 0.0.2 - Beta 1

- Update x3f_extract entitlements

# 0.0.1 - Initial Release

- Initial release of X3Fuse
- Convert Sigma X3F files to DNG format
- Support for multiple Sigma camera models (DPXM, DPXQ)
- Drag and drop interface for easy file processing
- Batch conversion capabilities
- Localization support for English, Korean, and Japanese
- Automatic opcode application for lens corrections

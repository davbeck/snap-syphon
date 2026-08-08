# snap-syphon

`snap-syphon` is a standalone macOS command-line client for discovering,
snapshotting, and recording local [Syphon](https://syphon.info/) sources.

The executable contains its Syphon client implementation, so it does not need a
separately installed framework or a framework borrowed from a publishing
application.

## Requirements

- macOS 13 or newer
- Swift 6.2 or newer to build
- A running Syphon server when capturing

## Build and test

Clone with the Syphon submodule:

```sh
git clone --recurse-submodules https://github.com/davbeck/snap-syphon.git
cd snap-syphon
```

Then build and test with Swift Package Manager:

```sh
swift build
swift test
swift build -c release
```

The release binary is written to `.build/release/snap-syphon`. Copy or move it
to any directory on your `PATH`.

To create a distributable universal binary for Apple Silicon and Intel Macs:

```sh
bin/build-release
```

The archive and its SHA-256 checksum are written to `dist`.
The binary is ad hoc signed by default. Set `CODESIGN_IDENTITY` to a Developer
ID Application identity to create a timestamped, hardened-runtime build.

## Usage

Discover sources:

```sh
snap-syphon list
snap-syphon list --json
```

Capture a PNG or JPEG:

```sh
snap-syphon snapshot frame.png --index 0
snap-syphon snapshot frame.jpg --source main --quality 0.9
```

Record H.264, HEVC, or ProRes video:

```sh
snap-syphon record clip.mov --index 0 --duration 5 --fps 30
snap-syphon record clip.mp4 --source main --duration 10 --codec hevc
snap-syphon record master.mov --index 0 --duration 5 --codec prores
```

Source selectors can use a list index, exact UUID, application-name match,
source-name match, or a combined free-text match. If only one source exists, no
selector is required.

Run `snap-syphon help` for every option.

## Stable-frame snapshots

Transient animations and overlays can make an arbitrary frame a poor snapshot.
The `--stable-frames` option waits until a run of sampled frames remains close
to the first frame in that run:

```sh
snap-syphon snapshot clean.png \
  --index 0 \
  --stable-frames 20 \
  --threshold 0.001 \
  --sample-rate 30 \
  --timeout 45
```

Frames are downsampled and compared by mean absolute RGB difference. The
threshold is a normalized fraction from `0` to `1`; `0` requires exact sampled
pixels, while the default `0.001` permits an average difference of 0.1%.
Comparing every candidate with the run's original anchor prevents a slow fade
from being treated as stable merely because adjacent frames are similar.

The same options can gate the start of a recording:

```sh
snap-syphon record clip.mov \
  --index 0 \
  --duration 5 \
  --stable-frames 20
```

## Output behavior

- Snapshots preserve the source resolution and support PNG and JPEG.
- Recordings preserve the source resolution and contain video only.
- MOV supports H.264, HEVC, and ProRes 422.
- MP4 supports H.264 and HEVC.
- Existing files are never replaced unless `--force` is supplied.

## Syphon source

Syphon is pinned as a Git submodule under `Vendor/Syphon`. The local `CSyphon`
target compiles the required client-side sources from that unmodified checkout.
[`Vendor/README.md`](Vendor/README.md) documents the integration and update
process.

## License

`snap-syphon` is available under the MIT License. See [`LICENSE`](LICENSE).
Third-party components retain their original licenses; see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

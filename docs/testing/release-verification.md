# Release verification

`ReleaseVerificationTests` is an opt-in integration suite. It executes all catalog conversion
routes, including Pages/Keynote/Numbers routes and legacy PPT/XLS input, then exercises each
tool/format pair allowed by the tool catalog and actual engine capabilities. It retains fixtures,
per-case inputs and outputs, `results.json`, and `REPORT.md` outside the repository.

Supply a private folder containing `image.png` (a portrait with a foreground subject) and one PDF.
Use an empty child folder for a fresh run. Place genuine legacy binary fixtures at
`fixtures/legacy/sample.ppt` and `fixtures/legacy/sample.xls` inside that child folder. Apache POI's
Apache-licensed [test data](https://github.com/apache/poi/tree/trunk/test-data) has suitable files, such as
`basic_test_ppt_file.ppt` and `Simple.xls`.

```sh
TRANSFLO_VERIFICATION_ROOT="/absolute/path/to/private-inputs/run" \
  swift test --package-path Packages/TransfloData --no-parallel --filter ReleaseVerificationTests
```

The suite creates the other format fixtures, a QR positive case, and private portrait copies for
background removal. It uses the same engine ordering as the app. iWork must be installed, and macOS
may request Automation consent. Helpers must be built in `Vendor/ffmpeg/bin`.

To rerun only tool checks while preserving conversion results:

```sh
TRANSFLO_VERIFICATION_ROOT="/absolute/path/to/private-inputs/run" \
TRANSFLO_VERIFICATION_PHASE=tools \
  swift test --package-path Packages/TransfloData --no-parallel \
  --filter ReleaseVerificationTests.verifyRelease
```

Each repeated case uses a new output directory, and the report replaces the previous row for that
case. A focused probe covers AVI speed accuracy and OGG/Opus metadata through the app reader.
Failures remain failures; a process exiting successfully is insufficient evidence of correctness.
`EXPECTED` identifies a deliberate no-content/already-optimized refusal. `HIDDEN` identifies a
catalog combination filtered out by the app's capability checks; it is not a passing tool run.

This verifies the selected fixtures on the current Mac. It does not guarantee arbitrary codecs,
malformed inputs, every value of interactive settings, every UI gesture, other macOS versions,
or behavior inside a distribution-signed App Sandbox. Keep the existing semantic, cancellation,
resource-limit, and UI regression suites alongside this sweep. TestFlight remains necessary for
sandbox and release-signing verification. Keep all private inputs and output artifacts out of Git.

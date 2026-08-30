# ASMR Route Package

`.asmrroute` is the ASMR Walk handoff package for the Mac importer and the future Final Cut Pro/Motion renderer. It is a directory package with deterministic JSON metadata and route data. The renderer should be able to load it without reaching back into iCloud, Photos, or an iPhone sandbox during timeline playback or export.

## Version 1 Layout

```text
Example Walk.asmrroute/
  manifest.json
  route-points.json
  source.gpx        optional
```

## `manifest.json`

The manifest is UTF-8 JSON encoded with stable sorted keys.

Required fields:

- `schemaVersion`: currently `1`.
- `packageIdentifier`: UUID, normally the ASMR Walk recording ID.
- `title`: display title.
- `createdAt`: ISO-8601 package/recording date.
- `durationSeconds`: recording duration.
- `mode`: ASMR Walk recording mode, such as `walk` or `videoWalk`.
- `recordingSource`: route source, such as `iPhone` or `appleWatch`.
- `routeStartedAt` and `routeEndedAt`: ISO-8601 timing anchors.
- `routePointCount`: expected number of points in `route-points.json`.
- `routePointsFile`: currently `route-points.json`.
- `videoReferences`: an array of non-embedded video references.
- `createdBy`: currently `ASMR Walk`.

Optional fields:

- `walkDescription`
- `distanceMeters`
- `captureDeviceName`
- `sourceGPXFile`

## `route-points.json`

Route points are stored in timestamp order. Each point can include:

- `timestamp`
- `latitude`
- `longitude`
- `altitude`
- `horizontalAccuracy`
- `speed`

## `source.gpx`

When a package is created from an explicit GPX import or export, the source GPX should be preserved as `source.gpx`. Package consumers should treat `manifest.json` and `route-points.json` as the normalized contract and `source.gpx` as provenance.

The GPX importer reads ASMR Walk export extensions when present. Generic GPX files can still produce packages, but fields such as recording ID, capture device, recording source, exact ASMR Walk duration, and external-camera timing may be missing or conservatively inferred from route point timestamps.

## Video References

Video files are not embedded by default. A video reference can represent:

- `localVideo`: an ASMR Walk in-app video on the source device. Do not store iPhone sandbox paths as portable package references.
- `photosAsset`: a user-selected Photos asset reference. Treat device-local Photos identifiers as hints, not globally portable IDs.
- `externalCamera`: a user-managed external clip label plus optional timing data.

Each video reference includes:

- `kind`
- `displayName`
- `sourceIdentifier`
- `startsAt`
- `offsetSeconds`
- `isEmbedded`

For Version 1.1.0, `isEmbedded` should normally be `false`. A later importer may add explicit user-controlled media copying, but the first renderer contract should not depend on Photos, iCloud, or large video files being available inside the package.

## Compatibility Rules

- Consumers must reject unsupported `schemaVersion` values.
- Consumers should verify that `routePointCount` matches the decoded route point file.
- Route rendering should rely on normalized route points, not `source.gpx` parsing.
- Missing video references must be shown as a recoverable state, not a package failure.

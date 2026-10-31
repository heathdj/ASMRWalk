# ASMR Route Package

`.asmrroute` is the ASMR Walk handoff package for the Mac importer and the future Final Cut Pro/Motion renderer. It is a directory package with deterministic JSON metadata and route data. The renderer should be able to load it without reaching back into iCloud, Photos, or an iPhone sandbox during timeline playback or export.

## Version 3 Layout

```text
Example Walk.asmrroute/
  manifest.json
  route-points.json
  source.gpx        optional
  map-background.png optional legacy single map
  map-background-001.png optional first segmented map
  map-background-002.png optional additional segmented maps
```

## `manifest.json`

The manifest is UTF-8 JSON encoded with stable sorted keys.

Required fields:

- `schemaVersion`: currently `3`; consumers continue to accept schema `1` route-only and schema `2` single-map packages.
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
- `primaryVideoReferenceIndex`: zero-based index of the video reference whose timing belongs to the edited clip.
- `mapBackground`
- `mapBackgrounds`

## Prepared Map Background

Schema 2 may include `map-background.png` plus a `mapBackground` manifest object. The object stores the portable relative filename, pixel width and height, image scale, and the exact MapKit Web Mercator map rectangle (`mapRectOriginX`, `mapRectOriginY`, `mapRectWidth`, and `mapRectHeight`) used to create the snapshot.

The Mac importer generates this asset only after an explicit **Prepare Map** action. FxPlug reads and caches the local PNG, projects route coordinates against the stored rectangle, and never contacts MapKit, Photos, CloudKit, or the network during timeline rendering or export. The renderer requires a PNG matching the manifest dimensions and valid positive scale/map bounds. Missing, corrupt, unsupported, or mismatched images fall back to the transparent route-only renderer, disable the map controls, and surface the reason through the plugin's Map Status field.

For routes over 100 points, schema 3 also offers **Prepare Segmented Maps**. Segments contain at most 100 points with a deterministic five-point overlap and use ordered names such as `map-background-001.png`. Every `mapBackgrounds` entry includes the same pixel and Web Mercator metadata as a single map plus inclusive route-point indices and start/end timestamps. FxPlug selects the segment from route time, keeps decoded images cached, and falls back to another usable segment or the transparent route when an asset is unavailable.

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

FxPlug uses `offsetSeconds` when present and otherwise derives the offset from `startsAt - routeStartedAt`. A positive value means the video begins after route recording, so the route is already that many seconds into the walk at the video's first frame. A negative value means the video begins before the route and the overlay remains at the route start until route time reaches zero. The inspector's manual timing offset is added to package timing. When a package has multiple video references it must declare `primaryVideoReferenceIndex`; consumers do not guess between ambiguous references.

For Version 1.1.0, `isEmbedded` should normally be `false`. A later importer may add explicit user-controlled media copying, but the first renderer contract should not depend on Photos, iCloud, or large video files being available inside the package.

## Compatibility Rules

- Consumers accept schema versions 1, 2, and 3 and must reject other values.
- Consumers should verify that `routePointCount` matches the decoded route point file.
- Route rendering should rely on normalized route points, not `source.gpx` parsing.
- Missing video references must be shown as a recoverable state, not a package failure.
- Map paths must remain relative to the package. Missing or corrupt map assets are recoverable route-only states.

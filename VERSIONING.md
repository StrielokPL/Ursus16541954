# Versioning and package identity

## Legacy conversion builds

`V1` through `V25` are historical conversion/build numbers used while bringing the original FS22 mod to Farming Simulator 25.

`V25 COLLISION SAFE` is the current playable legacy baseline and remains a valid historical reference/tag.

## Transition to the new version scheme

Before the transition, three remaining items must be completed and tested:

1. improve the switched-on lamp/emissive appearance,
2. lower the driver character model so it sits on the seat and no longer intersects the roof,
3. perform final log review and cleanup.

The completed and tested result becomes the first release in the new GIANTS-like four-part version scheme:

**`1.0.1.0`**

From `1.0.1.0` onward the project no longer uses `V26`, `V27`, etc. for public/build versioning. Legacy `Vxx` names remain only in changelog/history references.

## Four-part versions

Use the same four-part textual form in release naming and in `modDesc.xml`, for example:

- `1.0.1.0`
- `1.0.1.1`
- `1.0.2.0`
- `1.1.0.0`

Exact increment choice depends on the scope of the change; the important project rule is that all post-transition builds use this single four-part scheme consistently.

## Stable mod package identity

Starting with `1.0.1.0`, every downloadable mod build must use one constant ZIP filename:

`FS25_Ursus_1654_1954_Pack.zip`

Do **not** append the version, test number, tag, `SAFE`, or other suffix to the downloadable mod ZIP filename.

The version belongs in:

- `modDesc.xml`,
- Git tag / GitHub Release name,
- changelog/release notes,
- optional checksum filename or metadata.

The ZIP filename itself stays constant. This is intentional so replacing an older build with a newer build does not change the mod package identity expected by Farming Simulator saves.

## Savegame compatibility rules

To preserve existing purchased tractors and save references, do not casually rename or relocate:

- the release ZIP/mod package name,
- `Ursus1934.xml`,
- `Weight2500kg.xml`,
- store-item paths in `modDesc.xml`,
- custom specialization/script identities used by saved vehicles.

Any future change that alters one of these identity-bearing paths must be treated as a migration and checked against an existing save before release.

Ordinary updates to parameters, I3D data, textures, scripts, transmission behaviour, lights, sounds or configuration values may evolve while the stable package/file identity remains unchanged.

## GitHub Releases

Recommended post-transition release presentation:

- tag: `v1.0.1.0`
- title: `1.0.1.0`
- asset: `FS25_Ursus_1654_1954_Pack.zip`
- optional checksum: `FS25_Ursus_1654_1954_Pack.zip.sha256`

Test/pre-release builds may be marked as GitHub Pre-release, but the actual mod ZIP should still keep the same stable filename when it is intended to replace the installed mod for testing.

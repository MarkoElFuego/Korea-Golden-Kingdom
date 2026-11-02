# art/

Finished game models (.glb) go here. Rules for scale, pivot, markers, file names and budgets
are in [`docs/art-bible.md`](../docs/art-bible.md).

- `art/buildings/<building_id>.glb` (ids from `scripts/data/buildings.gd`)
- `art/houses/common_tier1.glb` ... `common_tier5.glb`
- `art/terrain/<terrain_id>.glb`
- `art/walkers/<walker_id>.glb`

When a file exists here, the game loads it instead of the placeholder model built in code.
Source files (.max, .blend, .psd) go to `art_src/`, templates to `art_templates/`.

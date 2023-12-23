# truenas-rename-snapshots
Batch rename truenas snapshots.

```bash
-d        Filter by day of week 0 (Sunday) to 6 (Saturday)
-f        Run the script and do the actual renaming. By default, the script will execuate as a DRY_RUN
          without actually renaming any files. Set this flag to execute the script.
-l        List snapshots only
-m        Match snapshots using Regex. Uses grep. Be careful when using the script in a FreeBSD environment
          as grep in FreeBSD is missing a lot of important features for grep.
-r        Recursive look up. Include children datasets when querying snapshots. Usually, either -r or -R
          flags are set and not both.
-R        Recursive rename. Rename datasets recursively. Usually, either -r or -R flags are set and not both.
```

## examples
Recursively rename snapshots from /tank/dataset1/child and its descendants
```bash
./rename -f -R -m "@auto" /tank/dataset1/child @auto @manual
---
previous snapshot name: /tank/dataset1/child/child@auto-2023-09-25_00-00
new snapshot name:      /tank/dataset1/child/child@daily-2023-09-25_00-00
```

Recursively retrieve snapshots from given dataset and rename them individually. This is much slower thatn the -r
version.
```bash
./rename -f -r -m "@auto" /tank/dataset1/child @auto @manual
---
previous snapshot name: /tank/dataset1/child/child@auto-2023-09-25_00-00
new snapshot name:      /tank/dataset1/child/child@daily-2023-09-25_00-00
```

Rename snapshots that fall on a given day of the week. The following example finds snapshots that fell on a Tuesday.
```bash
./rename -f -d 2 -m "@auto" /tank/dataset1/child @auto @manual
---
previous snapshot name: /tank/dataset1/child/child@auto-2023-12-17_00-00
new snapshot name:      /tank/dataset1/child/child@daily-2023-12-17_00-00
```

List only snapshots with matching string.
```bash
./rename -l -m "@auto" /tank/dataset1/child
example output
---
/tank/dataset1/child/child@auto-2023-12-10_00-00
/tank/dataset1/child/child@auto-2023-12-17_00-00
/tank/dataset1/child/child@auto-2023-12-24_00-00
```

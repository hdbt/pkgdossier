# pkgdossier: Compare What Users Meet Before and After a Package Upgrade

Runs the code users learned from a package's released version (its
vignettes, help-page examples or scenario scripts) unchanged under that
release and under a candidate version, each installed in its own library
and run in its own R process, and reports what a user meets after
upgrading: new errors and warnings, changed printed output, moved
numbers, removed or added object fields, changed plots and changes in
run time. Each difference is labelled mechanically; deciding whether it
is intended is left to the reader. Results are returned as data, written
as JSON and rendered as a standalone HTML report.

## See also

Useful links:

- <https://github.com/hdbt/pkgdossier>

- Report bugs at <https://github.com/hdbt/pkgdossier/issues>

## Author

**Maintainer**: Hamid Bulut <me@hamidbulut.com>

Authors:

- Hamid Bulut <me@hamidbulut.com>

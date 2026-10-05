# QuickJS-ng

The unchanged C sources of the JavaScript engine of the script runtime.

- Version: QuickJS-ng 0.17.0
- Source: <https://github.com/quickjs-ng/quickjs>, tag `v0.17.0`
- Archive SHA-256: `559bc4c420475e55c7ab4510adbc562f55d7524d75e8e89d79ce4bb02f5687d9`
- License: MIT (`LICENSE`)

This folder holds only the files that the library build needs. `build.rs`
compiles `quickjs.c`, `libregexp.c`, `libunicode.c` and `dtoa.c`. To update,
replace these files with the files of a new tag, then update the version here,
in `THIRD_PARTY_NOTICES.md` and in
`game/assets/licenses/quickjs`.

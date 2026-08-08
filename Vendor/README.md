# Vendored dependencies

`Syphon` is a Git submodule pinned to the upstream
[`Syphon/Syphon-Framework`](https://github.com/Syphon/Syphon-Framework)
repository. Clone this repository with `--recurse-submodules`, or initialize it
after cloning:

```sh
git submodule update --init --recursive
```

To update Syphon, check out the desired upstream commit inside `Vendor/Syphon`,
build and test the package, then commit the updated submodule pointer.

The `CSyphon` target under `Sources` contains a small Swift-facing adapter,
compatibility imports that replace the upstream Xcode prefix header, and thin
translation units that compile the required client-side sources directly from
the submodule. The upstream checkout remains unmodified.

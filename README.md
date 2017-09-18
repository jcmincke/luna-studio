# Luna Studio

## Requirements

TODO: GHC reqs

## Building
  1. Download `luna-manager` from http://luna-lang.org/luna-manager
  2. Use `bash` as your shell environment. Other shells will be supported in the future.
  3. Run `luna-manager develop luna-studio`, which will create a directory at `~/luna-develop`. You can optionally pass `--path PATH` command line argument to manually specify the destination.  
  4. For your convenience export following environment variables:
     * `export LUNA_DEV=~/luna-develop`
     * `export LUNA_STUDIO_DEV=$LUNA_DEV/apps/luna-studio`
  
  5. Change your working directory to `cd $LUNA_STUDIO_DEV`
  6. Run `./luna-shell.sh` which will setup your development environment.
  7. To build `luna-studio` from sources call `./build`. For further usage information call `./build --help`.
  8. After successful build you can test your new `luna-studio` version at `./dist/bin/main/luna-studio --develop`. Use `--help` for available running options.

## Build environment
  * Your luna-studio build environment `$LUNA_STUDIO_DEV` is a `git` repository and you can use it just as a regular source code repository.
  * If you use `git clean -x` git will remove the `$LUNA_STUDIO_DEV/dist` directory content, which contains dependencies needed for building `luna-studio`, which were downloaded there by `luna-manager`. To setup them again again call `luna-manager develop luna-studio --path $LUNA_STUDIO_DEV --download-dependencies`.
  

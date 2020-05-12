#!/bin/bash

omc_lib_path=$(pwd)/$(otool -l ./bin/omc | grep "@loader_path" | grep -o "lib/.*" | cut -d ' ' -f 1)

for bin in $(find bin -mindepth 1); do
  for lib_path in $(otool -l $bin | grep RPATH -A2 | grep path | awk '{print $2}' | grep -v "@.*path"); do
    install_name_tool -delete_rpath $lib_path $bin
  done

  install_name_tool -add_rpath @loader_path/../lib $bin 2> /dev/null

  for lib_path in $(otool -l $bin | grep -A2 LC_LOAD_DYLIB | grep dylib | grep name | awk '{print $2}' | grep -v "@.*path" | grep -v "^/usr/lib/" | grep -v "^/usr/local/lib/" | grep -v "^/System"); do
    lib_name_depend=$(echo $lib_path | awk -F'/' '{print $(NF)}')
    install_name_tool -change $lib_path @rpath/${lib_name_depend} $bin
    if [ -f "$lib_path" ]; then
      if [ ! -f "$omc_lib_path/${lib_name_depend}" ]; then
        cp $lib_path $omc_lib_path
      fi
    fi
  done
done

for lib in $(find lib -mindepth 1 -name "*.dylib"); do
  install_name_tool -id @rpath/$(basename $lib) $lib
  for lib_path in $(otool -l $lib | grep -A2 LC_LOAD_DYLIB | grep dylib | grep name | awk '{print $2}' | grep -v "@.*path" | grep -v "^/usr/lib/" | grep -v "^/usr/local/lib/" | grep -v "^/System"); do
    if [ -f "$lib_path" ]; then
      if [ ! -f "$omc_lib_path/$(basename $lib_path)" ]; then
        cp $lib_path $omc_lib_path
      fi
      if [ -f "$omc_lib_path/$(basename $lib_path)" ]; then
        for lib_path_dylib in $(otool -l $omc_lib_path/$(basename $lib_path) | grep -A2 LC_LOAD_DYLIB | grep dylib | grep name | awk '{print $2}' | grep -v "@.*path" | grep -v "^/usr/lib/" | grep -v "^/usr/local/lib/" | grep -v "^/System"); do
          install_name_tool -change $lib_path_dylib @rpath/$(echo $lib_path_dylib | awk -F'/' '{print $(NF)}') $omc_lib_path/$(basename $lib_path)
        done
        install_name_tool -id @rpath/$(basename $lib_path) $omc_lib_path/$(basename $lib_path)
      fi
      install_name_tool -change $lib_path @rpath/$(echo $lib_path | awk -F'/' '{print $(NF)}') $lib
    else
      echo "Warning: could not find $lib_path, you may have issues with this library at runtime."
    fi
  done
done

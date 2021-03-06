# bits of the build process that don't work from NimScript

import godotapigen, os, cpuinfo, cligen, strformat,
       compiler/nimeval

const STDLIB = find_nim_std_lib_compile_time()

proc core_count = echo count_processors()

proc copy_stdlib(destination: string) =
  remove_dir destination
  create_dir destination
  for path in @["core", "pure", "std", "fusion", "system"]:
    copy_dir join_path(STDLIB, path), join_path(destination, path)

  for file in @["system.nim", "prelude.nim", "stdlib.nimble"]:
    copy_file join_path(STDLIB, file),
              join_path(destination, file)

proc generate_api(directory = "godotapi", json = "api.json") =
  gen_api directory, join_path(directory, json)

dispatch_multi [generate_api], [core_count], [copy_stdlib]

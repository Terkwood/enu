### Sugar ###
from sugar import dup
import std/with, strformat, strutils, sequtils, sets, tables, times
export dup, with, strformat, strutils, sequtils, sets, tables

### Debug
from sugar import dump
import parseutils
export dump

var
  durations*: Table[string, Duration]
  log_trace* = false

template trace*(body: untyped): untyped =
  # https://github.com/nim-lang/Nim/issues/8212#issuecomment-657202258
  when not declaredInScope(internalCProcName):
    var internalCProcName {.exportc:"__the_name_should_not_be_used", inject.}: cstring
    {.emit: "__the_name_should_not_be_used = __func__;".}
    var realProcNameButShouldnotBeUsed {.inject.}: string
    discard parseUntil($internalCProcName, realProcNameButShouldnotBeUsed, "__")
  #/
  var proc_name = realProcNameButShouldnotBeUsed
  let file = instantiation_info().filename
  let start_time = now()
  body
  let
    name = file & "#" & proc_name
    duration = now() - start_time
  durations[name] = durations.get_or_default(name) + duration
  if log_trace:
    echo name, " took ", duration

### times ###
import times
export times

proc seconds*(s: float): TimeInterval {.inline.} =
  init_time_interval(milliseconds = int(s * 1000))

### options ###
import options
export options

converter to_option*[T](val: T): Option[T] =
  some(val)

converter to_bool*[T](option: Option[T]): bool =
  option.is_some

proc optional_get*[T](self: var HashSet[T], key: T): Option[T] =
  if key in self:
    result = some(self[key])
  else:
    result = none(T)

### Vector3 ###
import godot, math

proc vec3*(x, y, z: int): Vector3 {.inline.} =
  vec3(x.float, y.float, z.float)

proc trunc*(self: Vector3): Vector3 {.inline.} =
  vec3(trunc(self.x), trunc(self.y), trunc(self.z))

proc first*[T](arr: openArray[T], test: proc(x: T): bool): Option[T] =
  for item in arr:
    if test(item):
      return some(item)

### string ###
proc w*(str: string): seq[string] = str.split_whitespace()

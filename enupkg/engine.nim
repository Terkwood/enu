import compiler / [vm, vmdef, nimeval, options, lineinfos, ast, modules]
import os, strformat, std/with
import core
export Interpreter

export VmArgs, get_float, get_int, get_string, get_bool

type
  VMQuit* = object of CatchableError
    info*: TLineInfo
  VMPause* = object of CatchableError
  Routine = tuple[script_name, proc_name: string, routine: proc(a: VmArgs): bool]
  Engine* = ref object
    script_file: string
    i: Interpreter
    ctx: PCtx
    pc: int
    tos: PStackFrame
    initial_callbacks: int
    line_changed*: proc(current, previous: TLineInfo)
    current_line*: TLineInfo
    previous_line: TLineInfo
    initialized*: bool
    routines: seq[Routine]

const
  STDLIB = find_nim_std_lib_compile_time()

var
  free_interpreters: seq[Interpreter]
  total_interpreters = 0

proc pause*(e: Engine) =
  raise new_exception(VMPause, "vm paused")

proc implement(e: Engine, r: Routine) =
  e.i.implement_routine "*", r.script_name, r.proc_name, proc(a: VmArgs) {.gcsafe.} =
    if r.routine(a):
      e.pause()

proc restore_routines(e: Engine) =
  for r in e.routines:
    e.implement(r)

proc load*(e: Engine, script_file: string) =
  e.script_file = script_file
  if free_interpreters.len > 0:
    e.i = free_interpreters.pop()
    assert not e.i.is_nil
    var m = e.i.graph.make_module(script_file)
    incl(m.flags, sfMainModule)
    e.i.main_module = m
    e.i.script_name = script_file
    var ctx = PCtx e.i.graph.vm
    e.initial_callbacks = ctx.callbacks.high
    e.restore_routines()
  else:
    let source_paths = [STDLIB, STDLIB & "/core", STDLIB & "/pure",
                        STDLIB & "/pure/collections", parent_dir current_source_path]

    e.i = create_interpreter(script_file, source_paths)
    var ctx = PCtx e.i.graph.vm
    e.initial_callbacks = ctx.callbacks.high
    inc total_interpreters
  with e.i:
    register_error_hook proc(config, info, msg, severity: auto) {.gcsafe.} =
      if severity == Error and config.error_counter >= config.error_max:
        raise (ref VMQuit)(info: info, msg: msg)

    register_exit_hook proc(c, pc, tos: auto) =
      e.ctx = c
      e.pc = pc
      e.tos = tos

    register_enter_hook proc(c, pc, tos, instr: auto) =
      let info = c.debug[pc]
      if info.file_index.int == 0 and e.previous_line != info:
        if e.line_changed != nil:
          e.line_changed(info, e.previous_line)
        (e.previous_line, e.current_line) = (e.current_line, info)
  dump total_interpreters
  e.initialized = true

proc recycle_interpreter*(e: Engine) =
  var ctx = PCtx e.i.graph.vm
  ctx.callbacks = ctx.callbacks[0..e.initial_callbacks]
  free_interpreters.add e.i
  e.i = nil

proc run*(e: Engine): bool =
  if e.i.is_nil:
    e.load(e.script_file)
  try:
    e.i.eval_script()
    false
  except VMPause:
    true

proc to_node*(val: int): PNode =
  new_int_node(nk_int_lit, val)

proc to_node*(val: float): PNode =
  new_float_node(nk_float_lit, val)

proc to_node*(val: string): PNode =
  new_str_node(nk_str_lit, val)

proc to_node*(val: bool): PNode =
  let v = if val: 1 else: 0
  new_int_node(nk_int_lit, v)

proc call_proc*(e: Engine, proc_name: string, module_name = "", args: varargs[PNode, to_node]): PNode {.discardable.}=
  if e.i.is_nil:
    e.load(e.script_file)
  let foreign_proc = e.i.select_routine(proc_name, module_name = module_name)
  if foreign_proc == nil:
    quit &"script does not export a proc of the name: '{proc_name}'"
  return e.i.call_routine(foreign_proc, args)

proc call*(e: Engine, proc_name: string): bool =
  try:
    discard e.call_proc(proc_name)
    false
  except VMPause:
    true

proc expose*(e: Engine, script_name, proc_name: string,
             routine: proc(a: VmArgs): bool) {.gcsafe.} =
  let r = (script_name, proc_name, routine)
  e.routines.add r
  e.implement(r)

proc call_float*(e: Engine, proc_name: string): float =
  e.call_proc(proc_name).get_float()

proc get_var*(e: Engine, var_name: string, module_name: string): PNode =
  let sym = e.i.select_unique_symbol(var_name, module_name = module_name)
  e.i.get_global_value(sym)

proc get_float*(e: Engine, var_name: string, module_name = ""): float =
  e.get_var(var_name, module_name).get_float

proc get_int*(e: Engine, var_name: string, module_name = ""): int =
  e.get_var(var_name, module_name).get_int.to_int

proc get_bool*(e: Engine, var_name: string, module_name = ""): bool =
  let b = e.get_var(var_name, module_name).get_int
  return b == 1

proc call_int*(e: Engine, proc_name: string): int =
  e.call_proc(proc_name).get_int.to_int

proc resume*(e: Engine): bool =
  try:
    discard execFromCtx(e.ctx, e.pc + 1, e.tos)
    return false
  except VMPause:
    return true

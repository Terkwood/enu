proc forward*(steps = 1.0) = discard
proc back*(steps = 1.0)    = discard
proc left*(degrees = 90.0) = discard
proc right*(degrees = 90.0)= discard
proc fd*(steps = 1.0)      = forward(steps)
proc bk*(steps = 1.0)      = back(steps)
proc lt*(degrees = 90.0)   = left(degrees)
proc rt*(degrees = 90.0)   = right(degrees)
proc print*(msg: string)   = discard

template go*(rules) =
  proc run*() =
    rules
  
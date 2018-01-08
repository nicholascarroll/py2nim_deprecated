# we use our python-deduckt library to execute the python project
# and collect type data

import os, strformat, strutils, sequtils, future, osproc, tables, json
import python_ast, python_types, gen_kind

proc importType*(typ: JsonNode): PyType =
  if typ{"kind"} == nil:
    return nil
  var kind = ($typ{"kind"})[1..^2]
  for z in low(PyTypeKind)..high(PyTypeKind):
    if kind == $z:
      result = genKind(PyType, z)
      break
  case result.kind:
  of PyTypeFunction:
    result.args = @[]
    result.variables = @[]
    for v in typ{"args"}:
      var variable = PyVariable(name: ($v{"name"})[1..^2])
      variable.typ = importType(v{"type"})
      result.args.add(variable)
    for v in typ{"variables"}:
      var variable = PyVariable(name: ($v{"name"})[1..^2])
      variable.typ = importType(v{"type"})
      result.variables.add(variable)
    if typ{"returnType"} == nil:
      result.returnType = PyType(kind: PyTypeAtom, label: "void")
    else:
      result.returnType = importType(typ{"returnType"})
  of PyTypeConcrete, PyTypeUnion:
    result.types = (typ{"types"}).mapIt(importType(it))
  of PyTypeOptional:
    result.typ = importType(typ{"type"})
  of PyTypeObject:
    result.fields = @[]
    for field in typ{"fields"}:
      var variable = PyVariable(name: ($field{"name"})[1..^2])
      variable.typ = importType(field{"type"})
      result.fields.add(variable)
  of PyTypeGeneric:
    result.klass = typ{"klass"}.getStr()
    result.length = typ{"length"}.getInt()
  of PyTypeFunctionOverloads:
    result.overloads = (typ{"overloads"}).mapIt(importType(it))
  else:
    discard
  if typ{"label"} == nil:
    result.label = ""
  else:
    result.label = ($typ{"label"})[1..^2]

proc tracePython*(command: string) =
  echo fmt"python3 python-deduckt/deduckt/main.py {command}"
  var res = execProcess(fmt"python3 python-deduckt/deduckt/main.py {command}")
  # let types = parseJson(readFile("types.json"))
  # result[0] = initTable[string, PyType]()
  # result[1] = @[]
  # for label, child in types:
  #   if label != "@path":
  #     result[0][label] = importType(child)
  #   else:
  #     result[1] = child.mapIt(($it)[1..^2])

proc traceTemp*(path: string, source: string): (Table[string, PyType], seq[string]) =
  let newSource = source.splitLines().mapIt(fmt"  {it}").join("\n")
  let endl = "\n"
  writeFile("temp.py", fmt"def test():{endl}{newSource}{endl}")
  discard execProcess(fmt"python3 python-deduckt/deduckt/main.py {path}")
  let types = parseJson(readFile("types.json"))
  result[0] = initTable[string, PyType]()
  result[1] = @[]
  for label, child in types:
    if label != "@path":
      result[0][label] = importType(child)
    else:
      result[1] = child.mapIt(($it)[1..^2])

import Lean

def main (args : List String) : IO Unit := do
  let scriptPath := "test.sh"
  let child ← IO.Process.spawn {
    cmd := "bash"
    args := #[scriptPath] ++ args.toArray
  }
  let exitCode ← child.wait
  if exitCode != 0 then
    IO.Process.exit (UInt8.ofNat exitCode.toNat)

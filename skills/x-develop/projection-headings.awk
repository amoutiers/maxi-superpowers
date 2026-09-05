# Shared native heading map: v1 keeps its historical scan; v2 skips code fences.
# Output is projected-number|Maxi-id, in execution order.
NR == 1 && $0 == "---" { fm = 1; next }
fm && $0 == "sdd_projection: maxi-v2" { v2 = 1 }
fm && $0 == "---" { fm = 0; next }
fm { next }
v2 && /^```/ { fence = !fence; next }
!fence && /^### Task [1-9][0-9]*: T[0-9][0-9][0-9] / {
  number = $3; sub(/:$/, "", number)
  print number "|" $4
}

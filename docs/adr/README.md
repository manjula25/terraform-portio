# Architecture Decision Records

Create an Architecture Decision Record only when all three gates pass:

1. The decision is hard to reverse.
2. The choice is surprising without context.
3. Meaningful alternatives involve a real trade-off.

Use `ADR-TEMPLATE.md`; do not create records merely to document ordinary implementation detail.

A decision already recorded as a numbered requirement in `../../../mayo-port-prd.md` or `../../../mayo-port-build-spec.md` does not need a record here — that would create a second copy to drift. Records in this directory are for decisions **this repository** made that its specification does not cover.

| Record | Status |
|---|---|
| [ADR-001](ADR-001-per-stack-provider-and-state.md) — provider and backend configuration duplicated per stack | Accepted |

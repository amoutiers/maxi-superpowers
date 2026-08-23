# Review Contract Fixture Constitution

## Architecture ownership

- The routing module owns route evaluation from navigation inputs.
- The billing module owns subscription entitlement decisions.
- Routing must not decide whether a subscription is entitled to a feature.

## Verification

- Every new behavior requires an observable behavior test.

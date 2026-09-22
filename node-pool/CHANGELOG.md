# Changelog

## 1.1.0

- Pass all configurable AKS settings through the creation object, including security, identity, networking and fixed-size system pools.
- Validate additional-pool collisions with configurable system-pool rotation names.

## 1.0.0

- Add an autoscaled Linux user pool to a verified existing AKS cluster, or create network and AKS first.
- Exclusive cluster selection, resource ID, name, scaling, zone and tag guardrails.
- Tests for both modes and runnable examples for each path.

# Flagger Hostnameless Canary

## Overview

This project investigates and demonstrates that the `hosts` field in Flagger's Canary resources can be safely omitted when using Gateway API integration. This simplifies the configuration for canary deployments in Kubernetes environments.

## Key Findings

Our testing confirms that:

- The `hosts` field in Flagger's Canary resources is **optional**
- Omitting this field does not affect functionality
- HTTPRoutes are generated correctly even without explicit hostnames
- Canary releases work properly with simplified configuration

## Development Environment

This project uses [Devbox](https://www.jetify.com/devbox/) to provide a consistent development environment with all required tools:

- kubectl
- Kubernetes Helm
- Kind (Kubernetes in Docker)
- just (command runner)
- Chainsaw (Kubernetes testing tool)
- httpie

Simply [install Devbox](https://www.jetify.com/devbox/docs/installing_devbox/) and run:

```bash
devbox shell
```

This will automatically set up all the required tools.

## Setup

This repository includes a `justfile` with commands for easy setup:

```bash
# Create a Kind cluster and install all components
just setup

# Or install components individually
just install-gateway-api
just install-cert-manager
just install-envoy-gateway
just install-flagger

# Run tests
just test-hostnameless

# Clean up
just cleanup
```

## Test Procedure

The test validates that Flagger works correctly with Gateway API without specifying the `hosts` field:

1. Create a Gateway resource
2. Deploy a test application (podinfo)
3. Create a Canary resource without the `hosts` field
4. Verify initial configuration and access
5. Update the application version
6. Monitor the canary release progress
7. Verify successful promotion and access to the updated version

## Conclusion

This project demonstrates that when integrating Flagger with the Gateway API, the `hosts` field is optional. If you don't need routing based on specific hostnames, you can simply specify `gatewayRefs` to achieve canary releases with a simpler configuration.

## License

MIT

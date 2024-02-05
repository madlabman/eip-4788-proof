## EIP-4788 proofs verification

A set of scripts and on-chain code to use EIP-4788 block root to prove specific
properties of CL blocks.

## Usage

### Obtain proofs

```bash
cd script
yarn install

# Provide an address of a CL API endpoint.
export BEACON_NODE_URL=http://127.0.0.1:5052
node withdrawal.js
node validator.js
```

Look into the corresponding scripts and modify the required values such as
**slot**, **validator index**, **withdrawal index**.

The scripts output the data required too make a proof verifiable onchain with
the contracts presented in this repository. See tests for example usage.

The provided scripts were used to create fixtures for the tests.

### Tests

Foundry tests read JSON files fixtures and use the contracts from the repository
to accepts proofs.

```bash
forge test
```

To run forked tests, provide `FORK_URL` environment variable. Currently, the
Goerli is the only public network supporting EIP-4788.

```bash
FORK_URL=http://127.0.0.1:8545 forge test --mt Fork
```

### Gas Snapshots

```bash
$ forge snapshot
```

## EIP-4788 proofs verification

A set of scripts and on-chain code to use EIP-4788 block root to prove specific
properties of CL blocks.

## Usage

### Obtain proofs

```bash
cd script
yarn install

# To avoid downloading the same state multiple times reading from a local JSON
# file with a state structure is used. An example command for downloading a
# state are the following one. Choose the corresponding state identifier.
wget http://127.0.0.1:5052/eth/v2/debug/beacon/states/finalized > state.json

# Provide an address of a CL API endpoint.
export BEACON_NODE_URL=http://127.0.0.1:5052
# Reading a state from a json requires a lot of RAM, so override the default
# node head size.
node --max-old-space-size=4096 withdrawal.js
node --max-old-space-size=4096 validator.js
```

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

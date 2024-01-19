## EIP-4788 proofs verification

A set of scripts and on-chain code to use EIP-4788 block root to prove specific properties of CL blocks.

## Usage

### Obtain proofs

```bash
cd script
yarn install
# reading a state from a json requires a lot of RAM
node --max-old-space-size=4096 withdrawal.js
```

### Test

Foundry tests read JSON files fixtures and use the contracts from the repository to accepts proofs.

```shell
$ forge test
```

### Gas Snapshots

```shell
$ forge snapshot
```

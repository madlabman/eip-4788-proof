import { createProof, ProofType } from '@chainsafe/persistent-merkle-tree';
import { ssz } from '@lodestar/types';

import { createClient } from './client.js';
import { toHex, verifyProof } from './utils.js';

const BeaconBlock = ssz.deneb.BeaconBlock;

async function main(slot = 'finalized', withdrawalIndex = 0) {
    const client = await createClient();
    let r;

    // Requesting the corresponding beacon block to fetch withdrawals.
    r = await client.beacon.getBlockV2(slot);
    if (!r.ok) {
        throw r.error;
    }

    const blockView = BeaconBlock.toView(r.response.data.message);
    const blockRoot = blockView.hashTreeRoot();

    const nav = blockView.type.getPathInfo(['body', 'executionPayload', 'withdrawals', withdrawalIndex]);
    const p = createProof(blockView.node, { type: ProofType.single, gindex: nav.gindex });

    // Sanity check: verify gIndex and proof match.
    verifyProof(blockRoot, nav.gindex, p.witnesses, p.leaf);

    // Since EIP-4788 stores parentRoot, we have to find the descendant block of
    // the block from the state.
    r = await client.beacon.getBlockHeaders({ parentRoot: blockRoot });
    if (!r.ok) {
        throw r.error;
    }

    const nextBlock = r.response.data[0];
    if (!nextBlock) {
        throw new Error('No block to fetch timestamp from');
    }

    // Create output for the Verifier contract.
    return {
        blockRoot: toHex(blockRoot),
        proof: p.witnesses.map(toHex),
        withdrawal: nav.type.toJson(blockView.body.executionPayload.withdrawals.get(withdrawalIndex)),
        withdrawalIndex: withdrawalIndex,
        ts: client.slotToTS(nextBlock.header.message.slot),
        gI: nav.gindex,
    };
}

main(7424512, 9).then(console.log).catch(console.error);
//            ^_ withdrawal index in withdrawals array

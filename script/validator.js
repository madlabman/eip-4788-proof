import { ssz } from '@lodestar/types';
import { concatGindices, createProof, ProofType } from '@chainsafe/persistent-merkle-tree';

import { createClient } from './client.js';
import { toHex, verifyProof } from './utils.js';

const BeaconState = ssz.deneb.BeaconState;
const BeaconBlock = ssz.deneb.BeaconBlock;

async function main(slot = 0, validatorIndex = 0) {
    const client = await createClient();

    let r;

    r = await client.debug.getStateV2(slot, 'ssz');
    if (!r.ok) {
        throw r.error;
    }

    const stateView = BeaconState.deserializeToView(r.response);

    r = await client.beacon.getBlockV2(slot);
    if (!r.ok) {
        throw r.error;
    }

    const blockView = BeaconBlock.toView(r.response.data.message);
    const blockRoot = blockView.hashTreeRoot();

    const tree = blockView.tree.clone();
    // Patching the tree by attaching the state in the `stateRoot` field of the block.
    tree.setNode(blockView.type.getPropertyGindex('stateRoot'), stateView.node);
    // Create a proof for the state of the validator against the block.
    const gI = concatGindices([
        blockView.type.getPathInfo(['stateRoot']).gindex,
        stateView.type.getPathInfo(['validators', validatorIndex]).gindex,
    ]);
    const p = createProof(tree.rootNode, { type: ProofType.single, gindex: gI });

    // Sanity check: verify gIndex and proof match.
    verifyProof(blockRoot, gI, p.witnesses, stateView.validators.get(validatorIndex).hashTreeRoot());

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

    return {
        blockRoot: toHex(blockRoot),
        proof: p.witnesses.map(toHex),
        validator: stateView.validators.type.elementType.toJson(stateView.validators.get(validatorIndex)),
        validatorIndex: validatorIndex,
        ts: client.slotToTS(nextBlock.header.message.slot),
    };
}

main(7424512, 88888).then(console.log).catch(console.error);

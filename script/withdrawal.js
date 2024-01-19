// NOTE: run with node --max-old-space-size=4096 withdrawal.js
import fs from 'fs';

import Assembler from 'stream-json/Assembler.js';
import StreamChain from 'stream-chain';
import StreamJson from 'stream-json';

import { Tree, concatGindices } from '@chainsafe/persistent-merkle-tree';
import { ssz } from '@lodestar/types';

import { createClient } from './client.js';
import { toHex, verifyProof } from './utils.js';

async function main(withdrawalIndex = 0) {
    const client = await createClient();

    const { parser } = StreamJson;
    const { chain } = StreamChain;

    // @type {ssz.deneb.BeaconState}
    let state;

    // Reading previously downloaded state response from disk in a stream fashion (slot 7424512)
    // $ wget http://unstable.prater.beacon-api.nimbus.team/eth/v2/debug/beacon/states/7424512
    // NOTE: Alternatively, fetch the state using client.debug.getState('7424512');
    const pipeline = chain([fs.createReadStream('7424512'), parser()]);

    // creating a plain object from the read stream
    const asm = Assembler.connectTo(pipeline);
    let r = await new Promise((resolve) => {
        asm.on('done', function (r) {
            resolve(r.current);
        });
    });

    state = ssz.deneb.BeaconState.fromJson(r.data);
    const slot = state.slot;

    // requesting the corresponding beacon block to fetch withdrawals
    r = await client.beacon.getBlockV2(slot);
    if (!r.ok) {
        throw r.error;
    }

    // @type {ssz.deneb.BeaconBlock}
    const block = r.response.data.message;

    let tree,
        gI,
        p,
        overallProof,
        overallGi;

    // block.root -> state_root
    tree = new Tree(ssz.deneb.BeaconBlock.toView(block).node);
    gI = ssz.deneb.BeaconBlock.getPropertyGindex('stateRoot');
    p = tree.getSingleProof(gI);
    const blockRoot = tree.root;

    overallGi = gI;
    overallProof = [...p];

    // state_root -> withdrawals_root
    tree = new Tree(ssz.deneb.BeaconState.toView(state).node); // consumes a lot of memory
    gI = concatGindices([
        ssz.deneb.BeaconState.getPropertyGindex(
            'latestExecutionPayloadHeader'
        ),
        ssz.deneb.ExecutionPayloadHeader.getPropertyGindex('withdrawalsRoot'),
    ]);
    p = tree.getSingleProof(gI);

    overallGi = concatGindices([overallGi, gI]);
    // proofs are built from bottom up, so we need to prepend the proof
    overallProof = [...p, ...overallProof];

    // withdrawals_root -> withdrawal[idx].root
    tree = new Tree(
        ssz.capella.Withdrawals.toView(
            block.body.executionPayload.withdrawals
        ).node
    );
    gI = ssz.capella.Withdrawals.getPropertyGindex(withdrawalIndex);
    p = tree.getSingleProof(gI);

    overallGi = concatGindices([overallGi, gI]);
    overallProof = [...p, ...overallProof];

    const withdrawal = block.body.executionPayload.withdrawals[withdrawalIndex];
    tree = new Tree(ssz.capella.Withdrawal.toView(withdrawal).node);

    // Sanity check: verify gIndex and proof match.
    verifyProof(blockRoot, overallGi, overallProof, tree.root);

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

    // create output for the Verifier contract
    return {
        blockRoot: toHex(blockRoot),
        proof: overallProof.map(toHex),
        withdrawal: {
            ...withdrawal,
            address: toHex(withdrawal.address),
        },
        withdrawalIndex: withdrawalIndex,
        ts: client.slotToTS(nextBlock.header.message.slot),
    };

}

main(9).then(console.log).catch(console.error);
//   ^_ withdrawal index in withdrawals array

// NOTE: run with node --max-old-space-size=8192

import fs from 'fs';

import Assembler from 'stream-json/Assembler.js';
import StreamChain from 'stream-chain';
import StreamJson from 'stream-json';

import { Tree, concatGindices } from '@chainsafe/persistent-merkle-tree';
import { ssz } from '@lodestar/types';

import { client } from './client.js';
import { toHex, verifyProof } from './utils.js';

async function main(withdrawalIndex = 0) {
    const { parser } = StreamJson;
    const { chain } = StreamChain;

    // @type {ssz.capella.BeaconState}
    let state;

    // reading previously downloaded state response from disk in a stream fashion (slot 7913600)
    // $ wget http://testing.mainnet.beacon-api.nimbus.team/eth/v2/debug/beacon/states/7913600
    const pipeline = chain([fs.createReadStream('7913600'), parser()]);

    // creating a plain object from the read stream
    const asm = Assembler.connectTo(pipeline);
    let r = await new Promise((resolve) => {
        asm.on('done', function (r) {
            resolve(r.current);
        });
    });

    state = ssz.capella.BeaconState.fromJson(r.data);
    const slot = state.slot;

    // requesting the corresponding beacon block to fetch withdrawals
    r = await client.getBlockV2(slot);
    if (!r.ok) {
        throw r.error;
    }

    // @type {ssz.capella.BeaconBlock}
    const block = r.response.data.message;

    let tree,
        gI,
        p,
        overallProof,
        overallGi,
        ret = {};

    // block.root -> state_root
    tree = new Tree(ssz.capella.BeaconBlock.toView(block).node);
    gI = ssz.capella.BeaconBlock.getPropertyGindex('stateRoot');
    p = tree.getSingleProof(gI);
    const blockRoot = tree.root;

    overallGi = gI;
    overallProof = [...p];

    // state_root -> withdrawals_root
    tree = new Tree(ssz.capella.BeaconState.toView(state).node); // consumes a lot of memory
    gI = concatGindices([
        ssz.capella.BeaconState.getPropertyGindex('latestExecutionPayloadHeader'),
        ssz.capella.ExecutionPayloadHeader.getPropertyGindex('withdrawalsRoot'),
    ]);
    p = tree.getSingleProof(gI);

    overallGi = concatGindices([overallGi, gI]);
    // proofs are built from bottom up, so we need to prepend the proof
    overallProof = [...p, ...overallProof];

    // withdrawals_root -> withdrawal[idx].root
    tree = new Tree(ssz.capella.Withdrawals.toView(block.body.executionPayload.withdrawals).node);
    gI = ssz.capella.Withdrawals.getPropertyGindex(withdrawalIndex);
    p = tree.getSingleProof(gI);

    overallGi = concatGindices([overallGi, gI]);
    overallProof = [...p, ...overallProof];

    const withdrawal = block.body.executionPayload.withdrawals[withdrawalIndex];
    tree = new Tree(ssz.capella.Withdrawal.toView(withdrawal).node);

    // check
    verifyProof(blockRoot, overallGi, overallProof, tree.root);

    // create output for the Verifier contract
    ret = {
        ...ret,
        proof: overallProof.map(toHex),
        blockRoot: toHex(blockRoot),
        withdrawal: withdrawal,
    };

    return ret;
}

main(9).then(console.log).catch(console.error);
//   ^_ withdrawal index in withdrawals array

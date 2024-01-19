// NOTE: run with node --max-old-space-size=4096 validator.js
import fs from 'fs';

import Assembler from 'stream-json/Assembler.js';
import StreamChain from 'stream-chain';
import StreamJson from 'stream-json';

import { ssz } from '@lodestar/types';
import { Tree, concatGindices } from '@chainsafe/persistent-merkle-tree';

import { client } from './client.js';
import { toHex, verifyProof } from './utils.js';

async function main(validatorIndex = 0) {
    const { parser } = StreamJson;
    const { chain } = StreamChain;

    // Reading previously downloaded state response from disk in a stream fashion (slot 7424512)
    // $ wget http://unstable.prater.beacon-api.nimbus.team/eth/v2/debug/beacon/states/7424512
    // NOTE: Alternatively, fetch the state using client.debug.getState('7424512');
    const pipeline = chain([fs.createReadStream('7424512'), parser()]);

    // Creating a plain object from the read stream.
    const asm = Assembler.connectTo(pipeline);
    const json = await new Promise((resolve) => {
        asm.on('done', function (r) {
            resolve(r.current);
        });
    });

    const state = ssz.deneb.BeaconState.fromJson(json.data);

    // Find a block corresponding to the state.
    let r = await client.beacon.getBlockV2(state.slot);
    if (!r.ok) {
        throw r.error;
    }

    const block = r.response.data.message;

    // prettier-ignore
    let tree,
        gI,
        p,
        overallProof,
        overallGi;

    // block_root -> state_root
    tree = new Tree(ssz.deneb.BeaconBlock.toView(block).node);
    gI = ssz.deneb.BeaconBlock.getPropertyGindex('stateRoot');
    p = tree.getSingleProof(gI);
    const blockRoot = tree.root;

    overallGi = gI;
    overallProof = [...p];

    // state_root -> validators -> [validatorIndex]
    gI = concatGindices([
        ssz.deneb.BeaconState.getPropertyGindex('validators'),
        ssz.phase0.Validators.getPropertyGindex(validatorIndex),
    ]);

    tree = new Tree(ssz.deneb.BeaconState.toView(state).node);
    p = tree.getSingleProof(gI);

    overallGi = concatGindices([overallGi, gI]);
    // Proofs are built from bottom up, so we need to prepend the proof.
    overallProof = [...p, ...overallProof];

    const validator = state.validators[validatorIndex];
    tree = new Tree(ssz.phase0.Validator.toView(validator).node);

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

    return {
        proof: overallProof.map(toHex),
        validator: json.data.validators[validatorIndex],
        validatorIndex: validatorIndex,
        blockRoot: toHex(blockRoot),
        nextSlot: nextBlock.header.message.slot,
    };
}

main(44444).then(console.log).catch(console.error);

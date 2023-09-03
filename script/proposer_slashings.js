import { ssz } from '@lodestar/types';
import { Tree, concatGindices } from '@chainsafe/persistent-merkle-tree';

import { client } from './client.js';
import { toHex, verifyProof } from './utils.js';

async function main(slot = 6142320, validatorIndex = 552061) {
    const r = await client.getBlockV2(slot);
    if (!r.ok) {
        throw r.error;
    }

    const block = r.response.data.message;
    const blockView = ssz.bellatrix.BeaconBlock.toView(block); // NOTE: here is the bellatrix fork because slot is too old

    const i = block.body.proposerSlashings.findIndex((e) => e.signedHeader1.message.proposerIndex == validatorIndex);
    const slashing = block.body.proposerSlashings.at(i);

    console.log('slashing', slashing);

    if (!slashing) {
        throw new Error('slashing not found');
    }

    let tree,
        gI,
        p,
        node,
        ret = {};

    tree = new Tree(blockView.node);
    ret['block.root'] = toHex(tree.root);

    // All other indices should go through the point of gIndex of the slashing
    // We can use a lookup table to find the gIndex of the slashing 0..15
    const slashingGindex = concatGindices([
        blockView.type.getPropertyGindex('body'),
        blockView.body.type.getPropertyGindex('proposerSlashings'),
        blockView.body.proposerSlashings.type.getPropertyGindex(i), // slashing, i.e. SignedBeaconBlockHeader
    ]);
    ret['slashing.gIndex'] = slashingGindex;

    // Get proof of the validator index in the signedHeader1
    gI = concatGindices([
        slashingGindex,
        blockView.body.proposerSlashings.get(i).type.getPropertyGindex('signedHeader1'),
        blockView.body.proposerSlashings.get(i).signedHeader1.type.getPropertyGindex('message'),
        blockView.body.proposerSlashings.get(i).signedHeader1.message.type.getPropertyGindex('proposerIndex'),
    ]);
    console.log(gI);
    p = tree.getSingleProof(gI);
    // Check that the proof is valid
    console.log('Verify proof of the validator index in the signedHeader1');
    node = ssz.UintNum64.hashTreeRoot(validatorIndex);
    verifyProof(tree.root, gI, p, node);
    ret['signedHeader1.validatorIndex.proof'] = p.map(toHex);
    ret['signedHeader1.validatorIndex.node'] = toHex(node);
    ret['signedHeader1.validatorIndex.gIndex'] = gI;

    // Get proof of the slot in the signedHeader1
    gI = concatGindices([
        slashingGindex,
        blockView.body.proposerSlashings.get(i).type.getPropertyGindex('signedHeader1'),
        blockView.body.proposerSlashings.get(i).signedHeader1.type.getPropertyGindex('message'),
        blockView.body.proposerSlashings.get(i).signedHeader1.message.type.getPropertyGindex('slot'),
    ]);
    console.log(gI);
    p = tree.getSingleProof(gI);
    // Check that the proof is valid
    console.log('Verify proof of the slot in the signedHeader1');
    node = ssz.UintBn64.hashTreeRoot(slashing.signedHeader1.message.slot);
    verifyProof(tree.root, gI, p, node);
    ret['signedHeader1.slot.proof'] = p.map(toHex);
    ret['signedHeader1.slot.node'] = toHex(node);
    ret['signedHeader1.slot.gIndex'] = gI;

    return ret;
}

main().then(console.log).catch(console.error);

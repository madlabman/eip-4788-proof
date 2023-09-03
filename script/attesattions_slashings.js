import { ssz } from '@lodestar/types';
import { Tree, concatGindices } from '@chainsafe/persistent-merkle-tree';

import { client } from './client.js';
import { toHex, verifyProof } from './utils.js';

async function main(slot = 7185306, validatorIndex = 787006) {
    const r = await client.getBlockV2(slot);
    if (!r.ok) {
        throw r.error;
    }

    const block = r.response.data.message;
    const blockView = ssz.capella.BeaconBlock.toView(block);

    const sameIdxInBothAttestations = (a) =>
        a.attestation1.attestingIndices.includes(validatorIndex) &&
        a.attestation2.attestingIndices.includes(validatorIndex);

    const i = block.body.attesterSlashings.findIndex(sameIdxInBothAttestations);
    const slashing = block.body.attesterSlashings[i];

    console.log('slashing', slashing);

    if (!slashing) {
        throw new Error('slashing not found');
    }

    const byValidatorIndex = (i) => i == validatorIndex;

    let tree,
        gI,
        vI,
        p,
        node,
        ret = {};

    // Then get proof for the slot in the first attestation
    tree = new Tree(blockView.node);
    ret['block.root'] = toHex(tree.root);

    // Get proof of slot number
    gI = blockView.type.getPropertyGindex('slot');
    p = tree.getSingleProof(gI);
    // Check that the proof is valid
    console.log('Verify proof of slot number');
    node = tree.getNode(gI);
    verifyProof(tree.root, gI, p, node.root);
    ret['slot.proof'] = p.map(toHex);
    ret['slot.node'] = toHex(node.root); // LE bytes of slot number
    ret['slot.gIndex'] = gI; // is trusted

    // All other indices should go through the point of gIndex of the slashing
    const slashingGindex = concatGindices([
        blockView.type.getPropertyGindex('body'),
        blockView.body.type.getPropertyGindex('attesterSlashings'),
        blockView.body.attesterSlashings.type.getPropertyGindex(i), // slashing, i.e. IndexedAttestation
    ]);
    ret['slashing.gIndex'] = slashingGindex;

    // Get proof of the validator index in the attestation1
    vI = slashing.attestation1.attestingIndices.findIndex(byValidatorIndex);
    console.log(vI);
    gI = concatGindices([
        slashingGindex,
        blockView.body.attesterSlashings.get(i).type.getPropertyGindex('attestation1'),
        blockView.body.attesterSlashings.get(i).attestation1.type.getPropertyGindex('attestingIndices'),
        blockView.body.attesterSlashings.get(i).attestation1.attestingIndices.type.getPropertyGindex(vI),
    ]);
    p = tree.getSingleProof(gI);
    // Check that the proof is valid
    console.log('Verify proof of the validator index in the attestation1');
    node = tree.getNode(gI);
    verifyProof(tree.root, gI, p, node.root);
    ret['attestation1.validatorIndex.proof'] = p.map(toHex);
    ret['attestation1.validatorIndex.node'] = toHex(node.root);
    ret['attestation1.validatorIndex.offset'] = vI;
    ret['attestation1.validatorIndex.gIndex'] = gI;

    // Get proof of the validator index in the attestation2
    vI = slashing.attestation2.attestingIndices.findIndex(byValidatorIndex);
    console.log(vI);
    gI = concatGindices([
        slashingGindex,
        blockView.body.attesterSlashings.get(i).type.getPropertyGindex('attestation2'),
        blockView.body.attesterSlashings.get(i).attestation2.type.getPropertyGindex('attestingIndices'),
        blockView.body.attesterSlashings.get(i).attestation1.attestingIndices.type.getPropertyGindex(vI),
    ]);
    p = tree.getSingleProof(gI);
    // Check that the proof is valid
    console.log('Verify proof of the validator index in the attestation2');
    node = tree.getNode(gI);
    verifyProof(tree.root, gI, p, node.root);
    ret['attestation2.validatorIndex.proof'] = p.map(toHex);
    ret['attestation2.validatorIndex.node'] = toHex(node.root);
    ret['attestation2.validatorIndex.offset'] = vI;
    ret['attestation2.validatorIndex.gIndex'] = gI;

    return ret;
}

main().then(console.log).catch(console.error);

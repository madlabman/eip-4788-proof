import { ssz } from '@lodestar/types';
import { Tree, concatGindices } from '@chainsafe/persistent-merkle-tree';

import { client } from './client.js';
import { toHex } from './utils.js';

async function main(slot = 7172576, withdrawalIndex = 15213419) {
    const r = await client.getBlockV2(slot);
    if (!r.ok) {
        throw r.error;
    }

    const block = r.response.data.message;
    const findWithdrawal = (w) => w.index == withdrawalIndex;
    const i = block.body.executionPayload.withdrawals.findIndex(findWithdrawal);
    const withdrawal = block.body.executionPayload.withdrawals[i];

    if (!withdrawal) {
        throw new Error('withdrawal not found');
    }

    let tree,
        gI,
        p,
        ret = {};

    tree = new Tree(ssz.capella.BeaconBlock.toView(block).node);
    gI = concatGindices([
        ssz.capella.BeaconBlock.getPropertyGindex('body'),
        ssz.capella.BeaconBlockBody.getPropertyGindex('executionPayload'),
        ssz.capella.ExecutionPayload.getPropertyGindex('withdrawals'),
    ]);
    p = tree.getSingleProof(gI);

    ret['block.root'] = toHex(tree.root);
    ret['withdrawals.proof'] = p.map(toHex);

    tree = new Tree(ssz.capella.Withdrawals.toView(block.body.executionPayload.withdrawals).node);
    gI = ssz.capella.Withdrawals.getPropertyGindex(i);
    p = tree.getSingleProof(gI);

    ret['withdrawals.root'] = toHex(tree.root);
    ret['withdrawal.proof'] = p.map(toHex);

    return ret;
}

main().then(console.log).catch(console.error);

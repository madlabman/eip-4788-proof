import { getClient } from '@lodestar/api';
import { config } from '@lodestar/config/default';

function createClient() {
    const beaconNodeUrl = process.env.BEACON_NODE_URL;
    return getClient({ baseUrl: beaconNodeUrl, timeoutMs: 60_000 }, { config });
}

export const client = createClient();

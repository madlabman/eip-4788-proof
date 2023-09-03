import { getClient } from '@lodestar/api'
import { config } from '@lodestar/config/default'

function createClient() {
    const beaconNodeUrl = process.env.BEACON_NODE_URL
    return getClient({ baseUrl: beaconNodeUrl }, { config }).beacon
}

export const client = createClient()

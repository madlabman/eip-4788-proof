// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { BlockRootMock } from "./BlockRootMock.sol";
import { SSZ } from "./SSZ.sol";

contract SlashingVerifier {
    // Should be an address of EIP contract
    BlockRootMock public mockBlockRoot;

    // NOTE: not 100% sure about these values
    uint64[] signedHeader1MessageLookup = [
        99840, // <- this one is correct
        99856,
        99872,
        99888,
        99904,
        99920,
        99936,
        99952,
        99968,
        99984,
        100000,
        100016,
        100032,
        100048,
        100064,
        100080
    ];

    /// @notice Emitted when a proposer slashing is submitted
    event ProposerSlashingSubmitted(uint64 indexed validatorIndex, uint64 slot);

    constructor(address _mockBlockRoot) {
        mockBlockRoot = BlockRootMock(_mockBlockRoot);
    }

    function submitProposerSlashing(
        bytes32[] calldata multiProof,
        uint64 proposerIndex,
        uint64 slot,
        uint8 slashingIndex
    ) public {
        bytes32 blockRoot = mockBlockRoot.blockRoot();

        // Use both values to proove at the same time
        bytes32 leaf = sha256(
            abi.encodePacked(
                SSZ.toLittleEndian(slot), SSZ.toLittleEndian(proposerIndex)
            )
        );

        require(
            SSZ.verifyProof(
                multiProof,
                blockRoot,
                leaf,
                signedHeader1MessageLookup[slashingIndex]
            ),
            "invalid slot proof"
        );

        emit ProposerSlashingSubmitted(proposerIndex, slot);
    }
}

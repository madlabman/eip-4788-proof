// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { BlockRootMock } from "./BlockRootMock.sol";
import { SSZ } from "./SSZ.sol";

contract SlashingVerifier {
    // Should be an address of EIP contract
    BlockRootMock public mockBlockRoot;

    // NOTE: not 100% sure about these values
    uint64[16] signedHeader1MessageLookup = [
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

    uint64[2] attesterSlashingLookup = [785];

    // Should be a global index of the slot field in a block
    uint64 constant slotGindex = 8;

    /// @notice Emitted when a proposer slashing is submitted
    event ProposerSlashingSubmitted(uint64 indexed validatorIndex, uint64 slot);

    /// @notice Emitted when an attester slashing is submitted
    event AttesterSlashingSubmitted(uint64 indexed validatorIndex, uint64 slot);

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
            "invalid multiProof"
        );

        emit ProposerSlashingSubmitted(proposerIndex, slot);
    }

    // TODO: implement usage of multiProof
    function submitAttesterSlashing(
        bytes32[] calldata slotProof,
        uint64 slot,
        bytes32[] calldata attestation1Proof,
        uint64 attestation1Shift,
        bytes32 attestation1Node,
        bytes32[] calldata attestation2Proof,
        uint64 attestation2Shift,
        bytes32 attestation2Node,
        uint8 slashingIndex
    ) public {
        bytes32 blockRoot = mockBlockRoot.blockRoot();

        require(
            SSZ.verifyProof(
                slotProof, blockRoot, SSZ.toLittleEndian(slot), slotGindex
            ),
            "invalid slotProof"
        );

        uint64 attestation1gIndex = SSZ.concatGindices(
            attesterSlashingLookup[slashingIndex],
            8, // attestation1.attestingIndicies
            1024 + attestation1Shift / 4
        );

        require(
            SSZ.verifyProof(
                attestation1Proof,
                blockRoot,
                attestation1Node,
                attestation1gIndex
            ),
            "invalid attestation1IndexProof"
        );

        uint64 attesterIndex = uint64(
            uint256(
                SSZ.toLittleEndian(
                    uint256(attestation1Node << (attestation1Shift % 4))
                )
            )
        );

        uint64 attestation2gIndex = SSZ.concatGindices(
            attesterSlashingLookup[slashingIndex],
            12, // attestation2.attestingIndicies
            1024 + attestation2Shift / 4
        );

        require(
            SSZ.verifyProof(
                attestation2Proof,
                blockRoot,
                attestation2Node,
                attestation2gIndex
            ),
            "invalid attestation2IndexProof"
        );

        uint64 attesterIndexCopy = uint64(
            uint256(
                SSZ.toLittleEndian(
                    uint256(attestation2Node << (attestation2Shift % 4))
                )
            )
        );

        require(attesterIndex == attesterIndexCopy, "attesterIndex mismatch");
        // emit AttesterSlashingSubmitted(attesterIndex, slot);
    }
}

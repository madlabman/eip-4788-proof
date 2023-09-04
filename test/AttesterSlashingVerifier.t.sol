// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";

import { SSZ } from "../src/SSZ.sol";
import { BlockRootMock } from "../src/BlockRootMock.sol";
import { SlashingVerifier } from "../src/SlashingVerifier.sol";

contract AttesterSlashingVerifierTest is Test {
    using stdJson for string;

    struct ProofJson {
        bytes32[] slotProof;
        uint64 slot;
        bytes32[] attestation1Proof;
        bytes32 attestation1Node;
        uint64 attestation1Shift;
        bytes32[] attestation2Proof;
        bytes32 attestation2Node;
        uint64 attestation2Shift;
        uint8 slashingIndex;
        bytes32 blockRoot;
    }

    SlashingVerifier public verifier;
    BlockRootMock public blockRootMock;
    ProofJson public proofJson;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory path =
            string.concat(root, "/test/fixtures/attesterSlashing_proof.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw("$");
        proofJson = abi.decode(data, (ProofJson));
        blockRootMock = new BlockRootMock(proofJson.blockRoot);
        verifier = new SlashingVerifier(address(blockRootMock));
    }

    function test_SumbitProposerSlashing() public {
        // forgefmt: disable-next-item
        verifier.submitAttesterSlashing(
            proofJson.slotProof,
            proofJson.slot,
            proofJson.attestation1Proof,
            proofJson.attestation1Shift,
            proofJson.attestation1Node,
            proofJson.attestation2Proof,
            proofJson.attestation2Shift,
            proofJson.attestation2Node,
            proofJson.slashingIndex
        );
    }
}

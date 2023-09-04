// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";

import { SSZ } from "../src/SSZ.sol";
import { BlockRootMock } from "../src/BlockRootMock.sol";
import { SlashingVerifier } from "../src/SlashingVerifier.sol";

contract SlashingVerifierTest is Test {
    using stdJson for string;

    struct ProofJson {
        bytes32[] multiProof;
        uint64 proposerIndex;
        uint64 slot;
        uint8 slashingIndex;
        bytes32 blockRoot;
    }

    SlashingVerifier public verifier;
    BlockRootMock public blockRootMock;
    ProofJson public proofJson;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory path =
            string.concat(root, "/test/fixtures/proposerSlashing_proof.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw("$");
        proofJson = abi.decode(data, (ProofJson));
        blockRootMock = new BlockRootMock(proofJson.blockRoot);
        verifier = new SlashingVerifier(address(blockRootMock));
    }

    function test_SumbitProposerSlashing() public {
        // forgefmt: disable-next-item
        verifier.submitProposerSlashing(
            proofJson.multiProof,
            proofJson.proposerIndex,
            proofJson.slot,
            proofJson.slashingIndex
        );
    }
}

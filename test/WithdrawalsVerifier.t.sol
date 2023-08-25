// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";

import { SSZ } from "../src/SSZ.sol";
import { BlockRootMock } from "../src/BlockRootMock.sol";
import { WithdrawalsVerifier } from "../src/WithdrawalsVerifier.sol";

contract WithdrawalsVerifierTest is Test {
    using stdJson for string;

    struct ProofJson {
        bytes32[] blockWithdrawalsProof;
        bytes32 blockWithdrawalsRoot;
        bytes32[] withdrawalProof;
        SSZ.Withdrawal withdrawal;
        uint8 withdrawalIndex;
        bytes32 blockRoot;
    }

    WithdrawalsVerifier public verifier;
    BlockRootMock public blockRootMock;
    ProofJson public proofJson;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/fixtures/proof.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw("$");
        proofJson = abi.decode(data, (ProofJson));
        blockRootMock = new BlockRootMock(proofJson.blockRoot);
        verifier = new WithdrawalsVerifier(address(blockRootMock), 3230);
    }

    function test_SumbitWithdrawal() public {
        // forgefmt: disable-next-item
        verifier.submitWithdrawal(
            proofJson.blockWithdrawalsProof,
            proofJson.blockWithdrawalsRoot,
            proofJson.withdrawalProof,
            proofJson.withdrawal,
            proofJson.withdrawalIndex
        );
    }
}

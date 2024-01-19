// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";

import { SSZ } from "../src/SSZ.sol";
import { WithdrawalsVerifier } from "../src/WithdrawalsVerifier.sol";

contract WithdrawalsVerifierTest is Test {
    using stdJson for string;

    struct ProofJson {
        bytes32[] withdrawalProof;
        SSZ.Withdrawal withdrawal;
        uint8 withdrawalIndex;
        bytes32 blockRoot;
    }

    uint256 constant DENEB_ZERO_WITHDRAWAL_GINDEX = 385472;

    WithdrawalsVerifier public verifier;
    ProofJson public proofJson;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory path =
            string.concat(root, "/test/fixtures/withdrawal_proof.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw("$");
        proofJson = abi.decode(data, (ProofJson));
        verifier = new WithdrawalsVerifier(DENEB_ZERO_WITHDRAWAL_GINDEX);
    }

    function test_SubmitWithdrawal() public {
        uint64 ts = 31337;

        vm.mockCall(
            verifier.BEACON_ROOTS(),
            abi.encode(ts),
            abi.encode(proofJson.blockRoot)
        );

        // forgefmt: disable-next-item
        verifier.submitWithdrawal(
            proofJson.withdrawalProof,
            proofJson.withdrawal,
            proofJson.withdrawalIndex,
            ts
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { stdJson } from "forge-std/StdJson.sol";
import { Test } from "forge-std/Test.sol";
import { SSZ } from "../src/SSZ.sol";

contract SSZTest is Test {
    using stdJson for string;

    struct ProofJson {
        bytes32[] withdrawalsRoots;
        bytes32[] withdrawalsProof;
        SSZ.Withdrawal withdrawal;
        bytes32 blockRoot;
    }

    ProofJson public proofJson;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/fixtures/proof.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw("$");
        proofJson = abi.decode(data, (ProofJson));
    }

    function test_toLittleEndian() public {
        uint256 v = 0x1234567890ABCDEF;
        bytes32 expected =
            bytes32(bytes.concat(hex"EFCDAB9078563412", bytes24(0)));
        bytes32 actual = SSZ.toLittleEndian(v);
        assertEq(actual, expected);
    }

    /// Slot 7172576 withdrawal.at(0)
    function test_withdrawalRoot() public {
        SSZ.Withdrawal memory w = SSZ.Withdrawal({
            index: 15213404,
            validatorIndex: 429156,
            _address: 0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f,
            amount: 15428006
        });
        bytes32 expected =
            0x900838206a9d83fec95bd54289eb52a8500cbb4a198d000f9f9c2c0662bb8fa2;
        bytes32 actual = SSZ.withdrawalHashTreeRoot(w);
        assertEq(actual, expected);
    }

    function test_rootOfWithdrawalsList() public {
        bytes32 expected =
            0x00a0100281df021efc3a7bfa7e6cc47315b161f7cb6f087c62ddf8bc8adfb41d;
        bytes32 actual = SSZ.rootOfBytes32List(proofJson.withdrawalsRoots);
        assertEq(actual, expected);
    }
}

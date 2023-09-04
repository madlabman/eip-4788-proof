// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { SSZ } from "../src/SSZ.sol";

contract SSZTest is Test {
    function test_toLittleEndian() public {
        uint256 v = 0x1234567890ABCDEF;
        bytes32 expected =
            bytes32(bytes.concat(hex"EFCDAB9078563412", bytes24(0)));
        bytes32 actual = SSZ.toLittleEndian(v);
        assertEq(actual, expected);
    }

    function test_log2floor() public {
        uint64 v = 31;
        uint64 expected = 4;
        uint64 actual = uint64(SSZ.log2(v));
        assertEq(actual, expected);
    }

    function test_concatGIndicies() public {
        uint64 expected = 3230;
        uint64 actual = SSZ.concatGindices(12, 25, 30);
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
}

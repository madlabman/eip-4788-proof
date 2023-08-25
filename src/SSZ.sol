// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library SSZ {
    /// Withdrawal represents a validator withdrawal from the consensus layer.
    /// See EIP-4895: Beacon chain push withdrawals as operations.
    struct Withdrawal {
        uint64 index;
        uint64 validatorIndex;
        address _address;
        uint64 amount;
    }

    /// Inspired by https://github.com/succinctlabs/telepathy-contracts/blob/main/src/libraries/SimpleSerialize.sol#L59
    function withdrawalHashTreeRoot(Withdrawal memory withdrawal)
        internal
        pure
        returns (bytes32)
    {
        return sha256(
            bytes.concat(
                sha256(
                    bytes.concat(
                        toLittleEndian(withdrawal.index),
                        toLittleEndian(withdrawal.validatorIndex)
                    )
                ),
                sha256(
                    bytes.concat(
                        bytes20(withdrawal._address),
                        bytes12(0),
                        toLittleEndian(withdrawal.amount)
                    )
                )
            )
        );
    }

    // forgefmt: disable-next-item
    function toLittleEndian(uint256 v) internal pure returns (bytes32) {
        v =
            ((v &
                0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >>
                8) |
            ((v &
                0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) <<
                8);
        v =
            ((v &
                0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >>
                16) |
            ((v &
                0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) <<
                16);
        v =
            ((v &
                0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >>
                32) |
            ((v &
                0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) <<
                32);
        v =
            ((v &
                0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >>
                64) |
            ((v &
                0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) <<
                64);
        v = (v >> 128) | (v << 128);
        return bytes32(v);
    }

    // Even uglier implementation in Yul
    function rootOfBytes32List(bytes32[] memory values)
        internal
        view
        returns (bytes32 ret)
    {
        bytes32 lengthMixin = toLittleEndian(values.length);
        /// @solidity memory-safe-assembly
        assembly {
            if mload(values) {
                let l := mload(values)
                // Calculate width of the tree aligned to a power of 2
                let i := sub(l, 1)
                let w := 1
                for { } 1 { } {
                    w := shl(1, w)
                    i := shr(1, i)
                    if iszero(i) { break }
                }
                // Set `ptr` to point to the start of the free memory
                let ptr := mload(0x40)
                // Copy the values to the free memory
                let b := add(values, 0x20)
                for { i := 0 } lt(i, l) { i := add(i, 1) } {
                    mstore(ptr, mload(b))
                    ptr := add(ptr, 0x20)
                    b := add(b, 0x20)
                }
                ptr := mload(0x40)
                // Shift memory pointer
                // Calculate the root
                for { } 1 { } {
                    let leaf := ptr
                    let next := ptr
                    let end := add(ptr, shl(5, w))
                    for { } lt(leaf, end) { } {
                        if eq(w, 1) {
                            mstore(add(leaf, 0x20), lengthMixin)
                        }
                        let result :=
                            staticcall(gas(), 0x02, leaf, 0x40, next, 0x20)
                        // The branch below is copied from https://stackoverflow.com/a/75193208
                        // Revert if call failed
                        if eq(result, 0) {
                            // Forward the error
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }
                        leaf := add(leaf, 0x40)
                        next := add(next, 0x20)
                    }
                    w := shr(1, w)
                    if iszero(w) { break }
                }
                // Move free memory pointer
                mstore(0x40, add(ptr, 0x20))
                // Load the root
                ret := mload(ptr)
            }
        }
    }
}

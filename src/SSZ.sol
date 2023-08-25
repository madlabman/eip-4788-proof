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
}

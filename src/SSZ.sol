// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library SSZ {
    error BranchHasMissingItem();
    error BranchHasExtraItem();

    /// Withdrawal represents a validator withdrawal from the consensus layer.
    /// See EIP-4895: Beacon chain push withdrawals as operations.
    struct Withdrawal {
        uint64 index;
        uint64 validatorIndex;
        address _address;
        uint64 amount;
    }

    // As defined in phase0/beacon-chain.md:356
    struct Validator {
        bytes pubkey;
        bytes32 withdrawalCredentials;
        uint64 effectiveBalance;
        bool slashed;
        uint64 activationEligibilityEpoch;
        uint64 activationEpoch;
        uint64 exitEpoch;
        uint64 withdrawableEpoch;
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

    function validatorHashTreeRoot(Validator memory validator)
        internal
        view
        returns (bytes32 root)
    {
        bytes32 pubkeyRoot;

        assembly {
            // Dynamic data types such as bytes are stored at the specified offset.
            let offset := mload(validator)
            // Call sha256 precompile with the pubkey pointer
            let result :=
                staticcall(gas(), 0x02, add(offset, 32), 0x40, 0x00, 0x20)
            // The branch below is copied from https://stackoverflow.com/a/75193208
            // Revert if call failed
            if eq(result, 0) {
                // Forward the error
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            pubkeyRoot := mload(0x00)
        }

        bytes32[8] memory nodes = [
            pubkeyRoot,
            validator.withdrawalCredentials,
            toLittleEndian(validator.effectiveBalance),
            toLittleEndian(validator.slashed ? 1 : 0),
            toLittleEndian(validator.activationEligibilityEpoch),
            toLittleEndian(validator.activationEpoch),
            toLittleEndian(validator.exitEpoch),
            toLittleEndian(validator.withdrawableEpoch)
        ];

        /// @solidity memory-safe-assembly
        assembly {
            // Count of nodes to hash
            let count := 8

            // Loop over levels
            for { } 1 { } {
                // Loop over nodes at the given depth

                // Initialize `offset` to the offset of `proof` elements in memory.
                let target := nodes
                let source := nodes
                let end := add(source, shl(5, count))

                for { } 1 { } {
                    // Read next two hashes to hash
                    mstore(0x00, mload(source))
                    mstore(0x20, mload(add(source, 0x20)))

                    // Call sha256 precompile
                    let result :=
                        staticcall(gas(), 0x02, 0x00, 0x40, 0x00, 0x20)
                    // The branch below is copied from https://stackoverflow.com/a/75193208
                    // Revert if call failed
                    if eq(result, 0) {
                        // Forward the error
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    // Store the resulting hash at the target location
                    mstore(target, mload(0x00))

                    // Advance the pointers
                    target := add(target, 0x20)
                    source := add(source, 0x40)

                    if iszero(lt(source, end)) { break }
                }

                count := shr(1, count)
                if eq(count, 1) {
                    root := mload(0x00)
                    break
                }
            }
        }
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

    /// @notice Modified version of `verify` from `MerkleProofLib` to support generalized indices and sha256 precompile
    /// @dev Returns whether `leaf` exists in the Merkle tree with `root`, given `proof`.
    function verifyProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf,
        uint64 index
    ) internal view returns (bool isValid) {
        /// @solidity memory-safe-assembly
        assembly {
            if proof.length {
                // Left shift by 5 is equivalent to multiplying by 0x20.
                let end := add(proof.offset, shl(5, proof.length))
                // Initialize `offset` to the offset of `proof` in the calldata.
                let offset := proof.offset
                // Iterate over proof elements to compute root hash.
                for { } 1 { } {
                    // Slot of `leaf` in scratch space.
                    // If the condition is true: 0x20, otherwise: 0x00.
                    let scratch := shl(5, and(index, 1))
                    index := shr(1, index)
                    if iszero(index) {
                        // revert BranchHasExtraItem()
                        mstore(0x00, 0x5849603f)
                        revert(0x1c, 0x04)
                    }
                    // Store elements to hash contiguously in scratch space.
                    // Scratch space is 64 bytes (0x00 - 0x3f) and both elements are 32 bytes.
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), calldataload(offset))
                    // Call sha256 precompile
                    let result :=
                        staticcall(gas(), 0x02, 0x00, 0x40, 0x00, 0x20)
                    // The branch below is copied from https://stackoverflow.com/a/75193208
                    // Revert if call failed
                    if eq(result, 0) {
                        // Forward the error
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    // Reuse `leaf` to store the hash to reduce stack operations.
                    leaf := mload(0x00)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            // index != 1
            if gt(sub(index, 1), 0) {
                // revert BranchHasMissingItem()
                mstore(0x00, 0x1b6661c3)
                revert(0x1c, 0x04)
            }
            isValid := eq(leaf, root)
        }
    }

    // TODO: optimize
    function concatGindices(uint64 a, uint64 b, uint64 c)
        internal
        pure
        returns (uint64)
    {
        return concatGindices(concatGindices(a, b), c);
    }

    function concatGindices(uint64 a, uint64 b)
        internal
        pure
        returns (uint64)
    {
        uint64 powOf2floor = uint64(1 << log2(b));
        return a * powOf2floor + (b - powOf2floor);
    }

    /// @dev From solady FixedPointMath
    /// @dev Returns the log2 of `x`.
    /// Equivalent to computing the index of the most significant bit (MSB) of `x`.
    function log2(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(x) {
                // Store the function selector of `Log2Undefined()`.
                mstore(0x00, 0x5be3aa5c)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))

            // For the remaining 32 bits, use a De Bruijn lookup.
            // See: https://graphics.stanford.edu/~seander/bithacks.html
            x := shr(r, x)
            x := or(x, shr(1, x))
            x := or(x, shr(2, x))
            x := or(x, shr(4, x))
            x := or(x, shr(8, x))
            x := or(x, shr(16, x))

            // forgefmt: disable-next-item
            r := or(r, byte(shr(251, mul(x, shl(224, 0x07c4acdd))),
                0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f))
        }
    }
}

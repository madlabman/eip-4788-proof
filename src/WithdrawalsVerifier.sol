// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { BlockRootMock } from "./BlockRootMock.sol";
import { SSZ } from "./SSZ.sol";

contract WithdrawalsVerifier {
    // Should be an address of EIP contract
    BlockRootMock public mockBlockRoot;

    // Generalized index of withdrawals
    uint64 public immutable gIndex;

    /// @notice Emitted when a withdrawal is submitted
    event WithdrawalSubmitted(uint64 indexed validatorIndex, uint64 amount);

    error BranchHasMissingItem();
    error BranchHasExtraItem();

    constructor(address _mockBlockRoot, uint64 _gIndex) {
        mockBlockRoot = BlockRootMock(_mockBlockRoot);
        gIndex = _gIndex;
    }

    function submitWithdrawal(
        bytes32[] memory blockWithdrawalsProof,
        bytes32 blockWithdrawalsRoot,
        bytes32[] memory withdrawalProof,
        SSZ.Withdrawal memory withdrawal,
        uint8 withdrawalIndex
    ) public {
        bytes32 withdrawalRoot = SSZ.withdrawalHashTreeRoot(withdrawal);
        require(
            _verifyProof(
                withdrawalProof,
                blockWithdrawalsRoot,
                withdrawalRoot,
                withdrawalIndex
            ),
            "invalid withdrawal proof"
        );

        bytes32 blockRoot = mockBlockRoot.blockRoot();

        require(
            _verifyProof(
                blockWithdrawalsProof, blockRoot, blockWithdrawalsRoot, gIndex
            ),
            "invalid withdrawals proof"
        );

        emit WithdrawalSubmitted(withdrawal.validatorIndex, withdrawal.amount);
    }

    /// @notice Modified version of `verify` from `MerkleProofLib` to support generalized indices and sha256 precompile
    /// @dev Returns whether `leaf` exists in the Merkle tree with `root`, given `proof`.
    function _verifyProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf,
        uint64 index
    ) internal view returns (bool isValid) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(proof) {
                // Initialize `offset` to the offset of `proof` elements in memory.
                let offset := add(proof, 0x20)
                // Left shift by 5 is equivalent to multiplying by 0x20.
                let end := add(offset, shl(5, mload(proof)))
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
                    mstore(xor(scratch, 0x20), mload(offset))

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
}

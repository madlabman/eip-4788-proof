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

    constructor(address _mockBlockRoot, uint64 _gIndex) {
        mockBlockRoot = BlockRootMock(_mockBlockRoot);
        gIndex = _gIndex;
    }

    function submitWithdrawal(
        bytes32[] calldata blockWithdrawalsProof,
        bytes32 blockWithdrawalsRoot,
        bytes32[] calldata withdrawalProof,
        SSZ.Withdrawal memory withdrawal,
        uint8 withdrawalIndex
    ) public {
        bytes32 withdrawalRoot = SSZ.withdrawalHashTreeRoot(withdrawal);
        require(
            SSZ.verifyProof(
                withdrawalProof,
                blockWithdrawalsRoot,
                withdrawalRoot,
                withdrawalIndex
            ),
            "invalid withdrawal proof"
        );

        bytes32 blockRoot = mockBlockRoot.blockRoot();

        require(
            // forgefmt: disable-next-item
            SSZ.verifyProof(
                blockWithdrawalsProof,
                blockRoot,
                blockWithdrawalsRoot,
                gIndex
            ),
            "invalid withdrawals proof"
        );

        emit WithdrawalSubmitted(withdrawal.validatorIndex, withdrawal.amount);
    }
}

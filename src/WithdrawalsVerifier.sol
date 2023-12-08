// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { BlockRootMock } from "./BlockRootMock.sol";
import { SSZ } from "./SSZ.sol";

contract WithdrawalsVerifier {
    // Should be an address of EIP contract
    BlockRootMock public mockBlockRoot;

    uint64 constant MAX_WITHDRAWALS = 2 ** 4;

    // Generalized index of withdrawalsRoot
    uint64 public immutable gIndex;

    /// @notice Emitted when a withdrawal is submitted
    event WithdrawalSubmitted(uint64 indexed validatorIndex, uint64 amount);

    constructor(address _mockBlockRoot, uint64 _gIndex) {
        mockBlockRoot = BlockRootMock(_mockBlockRoot);
        gIndex = _gIndex;
    }

    function submitWithdrawal(
        bytes32[] calldata withdrawalProof,
        SSZ.Withdrawal memory withdrawal,
        uint8 withdrawalIndex
    ) public {
        uint64 gI = /* shifting MAX_WITHDRAWALS because of mix_in_length during merkleization */
            SSZ.concatGindices(gIndex, (MAX_WITHDRAWALS << 1) | withdrawalIndex);
        bytes32 withdrawalRoot = SSZ.withdrawalHashTreeRoot(withdrawal);
        bytes32 blockRoot = mockBlockRoot.blockRoot();

        require(
            // forgefmt: disable-next-item
            SSZ.verifyProof(
                withdrawalProof,
                blockRoot,
                withdrawalRoot,
                gI
            ),
            "invalid withdrawal proof"
        );

        emit WithdrawalSubmitted(withdrawal.validatorIndex, withdrawal.amount);
    }
}

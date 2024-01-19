// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { SSZ } from "./SSZ.sol";

contract ValidatorVerifier {
    address public constant BEACON_ROOTS =
        0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    uint64 constant VALIDATOR_REGISTRY_LIMIT = 2 ** 40;

    /// @dev Generalized index of the first validator struct root in the
    /// registry.
    uint256 public immutable gIndex;

    event Accepted(uint64 indexed validatorIndex);

    error RootNotFound();

    constructor(uint256 _gIndex) {
        gIndex = _gIndex;
    }

    function proveValidator(
        bytes32[] calldata validatorProof,
        SSZ.Validator calldata validator,
        uint64 validatorIndex,
        uint64 ts
    ) public {
        require(
            validatorIndex < VALIDATOR_REGISTRY_LIMIT,
            "validator index out of range"
        );

        uint256 gI = gIndex | validatorIndex;
        bytes32 validatoRoot = SSZ.validatorHashTreeRoot(validator);
        bytes32 blockRoot = getParentBlockRoot(ts);

        require(
            // forgefmt: disable-next-item
            SSZ.verifyProof(
                validatorProof,
                blockRoot,
                validatoRoot,
                gI
            ),
            "invalid validator proof"
        );

        emit Accepted(validatorIndex);
    }

    function getParentBlockRoot(uint64 ts)
        internal
        view
        returns (bytes32 root)
    {
        (bool success, bytes memory data) =
            BEACON_ROOTS.staticcall(abi.encode(ts));

        if (!success || data.length == 0) {
            revert RootNotFound();
        }

        root = abi.decode(data, (bytes32));
    }
}

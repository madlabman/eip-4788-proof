// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract BlockRootMock {
    bytes32 public immutable blockRoot;

    constructor(bytes32 _blockRoot) {
        blockRoot = _blockRoot;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract AttestationRegistry {
    mapping(uint64 => bool) public valid;
    function isValid(uint64 id, address subject) external view returns (bool) { return true; }
}

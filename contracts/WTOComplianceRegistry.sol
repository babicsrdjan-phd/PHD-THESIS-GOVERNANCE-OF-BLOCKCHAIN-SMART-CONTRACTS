// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WTOComplianceRegistry
 * @notice Enforces WTO-alignment precondition for all CEFTA
 *         trade operations (CEFTA Preamble, Article 2).
 */
contract WTOComplianceRegistry is Ownable {
    bool public ceftaWTOAligned = true;
    event AlignmentChanged(bool status);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function verifyAlignment() external view returns (bool) {
        return ceftaWTOAligned;
    }

    function setAlignment(bool status) external onlyOwner {
        ceftaWTOAligned = status;
        emit AlignmentChanged(status);
    }
}

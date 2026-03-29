// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OriginProtocolRegistry
 * @notice Implements CEFTA Annex 4 origin verification:
 *         Art.5 (wholly obtained), Art.6 (sufficient processing,
 *         <=10% non-originating), Art.7 (insufficient operations).
 */
contract OriginProtocolRegistry is Ownable {

    constructor(address initialOwner) Ownable(initialOwner) {}

    enum OriginType { None, WhollyObtained, SufficientlyProcessed }

    struct OriginCertificate {
        OriginType originType;
        uint256    nonOriginatingValuePercent; // Art.6 threshold
        bool       insufficientProcessing;     // Art.7 violation flag
    }

    mapping(bytes32 => OriginCertificate) public certificates;

    event OriginRegistered(bytes32 certHash, OriginType originType);

    function registerCertificate(
        bytes32    certHash,
        OriginType originType,
        uint256    nonOriginatingPercent,
        bool       insufficientProcessing
    ) external onlyOwner {
        certificates[certHash] = OriginCertificate(
            originType, nonOriginatingPercent, insufficientProcessing
        );
        emit OriginRegistered(certHash, originType);
    }

    /**
     * @notice Verify origin against Annex 4 criteria.
     * @dev    Checks existence first, then Art.7 violation,
     *         then Art.5/Art.6 criteria. Reverts as fallback.
     */
    function verifyOrigin(bytes32 certHash) 
        external view returns (bool) 
    {
        OriginCertificate memory c = certificates[certHash];
        require(c.originType != OriginType.None, 
            "Certificate not registered");
        require(!c.insufficientProcessing, 
            "Insufficient processing - Art7");
        if (c.originType == OriginType.WhollyObtained) return true;
        if (c.originType == OriginType.SufficientlyProcessed &&
            c.nonOriginatingValuePercent <= 10) return true;
        revert("Invalid proof of origin");
    }
}

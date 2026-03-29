// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EmergencySafeguard
 * @notice Implements CEFTA Articles 23-26 / WTO Safeguards
 *         Agreement. Allows temporary tariff override with
 *         mandatory auto-expiration.
 * @dev    stateAuthority is the Ownable owner; activateSafeguard
 *         uses onlyOwner for access control.
 */
contract EmergencySafeguard is Ownable {
    struct Safeguard {
        bool active;
        uint256 overrideDuty; // Override duty rate (%)
        uint256 expiry; // Block timestamp of expiration
    }

    mapping(string => mapping(string => Safeguard)) public safeguards;

    event SafeguardActivated(
        string importer,
        string hsCode,
        uint256 duty,
        uint256 expiry
    );
    event SafeguardExpired(string importer, string hsCode);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function activateSafeguard(
        string memory importer,
        string memory hsCode,
        uint256 overrideDuty,
        uint256 duration
    ) external onlyOwner {
        uint256 exp = block.timestamp + duration;
        safeguards[importer][hsCode] = Safeguard(true, overrideDuty, exp);
        emit SafeguardActivated(importer, hsCode, overrideDuty, exp);
    }

    function getSafeguardDuty(
        string memory importer,
        string memory hsCode
    ) external view returns (bool active, uint256 duty) {
        Safeguard memory s = safeguards[importer][hsCode];
        if (s.active && block.timestamp <= s.expiry) {
            return (true, s.overrideDuty);
        }
        return (false, 0);
    }
}

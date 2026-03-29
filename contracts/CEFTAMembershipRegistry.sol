// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CEFTAMembershipRegistry
 * @notice Implements CEFTA 2006 membership verification with EU
 *         withdrawal auto-trigger (Article 49).
 * @dev Encodes Group A (active), Group B (excluded), and
 *      EU-withdrawn members as enumerated states.
 * @dev Source: https://github.com/babicsrdjan-phd/PHD_Cefta-Smart-Contract
 */
contract CEFTAMembershipRegistry is Ownable {
    enum MemberStatus { None, Active, Withdrawn }
    mapping(string => MemberStatus) public members;
    event MemberStatusChanged(string country, MemberStatus status);

    constructor(address initialOwner) Ownable(initialOwner) {
        // GROUP A: Active CEFTA 2006 signatories
        members["Albania"] = MemberStatus.Active;
        members["Bosnia and Herzegovina"] = MemberStatus.Active;
        members["Macedonia"] = MemberStatus.Active;
        members["Moldova"] = MemberStatus.Active;
        members["Montenegro"] = MemberStatus.Active;
        members["Serbia"] = MemberStatus.Active;
        members["Kosovo"] = MemberStatus.Active;

        // GROUP B: Never signatories to CEFTA 2006
        members["Czech Republic"] = MemberStatus.None;
        members["Hungary"] = MemberStatus.None;
        members["Poland"] = MemberStatus.None;
        members["Slovakia"] = MemberStatus.None;
        members["Slovenia"] = MemberStatus.None;

        // EU-accession withdrawals (Article 49)
        members["Bulgaria"] = MemberStatus.Withdrawn;
        members["Croatia"] = MemberStatus.Withdrawn;
        members["Romania"] = MemberStatus.Withdrawn;
    }

    function verifyMember(string memory country)
        public view returns (bool)
    {
        return members[country] == MemberStatus.Active;
    }

    function triggerEUWithdrawal(string memory country)
        external onlyOwner
    {
        require(
            members[country] == MemberStatus.Active,
            "Not an active member"
        );
        members[country] = MemberStatus.Withdrawn;
        emit MemberStatusChanged(country, MemberStatus.Withdrawn);
    }
}



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title JointCommittee
 * @notice Implements CEFTA Joint Committee governance (Art. 40).
 *         Provides proposal, voting, and execution lifecycle.
 */
contract JointCommittee is Ownable {
    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        uint256 createdAt;
    }

    mapping(string => bool) public votingMembers;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(string => bool)) public voted;
    uint256 public proposalCount;

    address[] members;

    event ProposalCreated(uint256 id, string description);
    event VoteCast(uint256 id, string country, bool support);
    event ProposalExecuted(uint256 id);

    constructor(
        address initialOwner,
        string[] memory members // adddress[] memory members -> ovo su adresee za svaku drzavu clanicu po jedna
    ) Ownable(initialOwner) {
        for (uint i = 0; i < members.length; i++) {
            votingMembers[members[i]] = true;
        }
    }

    //onlyMember
    function propose(string memory description) external {
        proposals[proposalCount] = Proposal(
            description,
            0,
            0,
            false,
            block.timestamp
        );
        emit ProposalCreated(proposalCount, description);
        proposalCount++;
    }

    //onlyMember
    function vote(
        uint256 proposalId,
        //brises country
        string memory country,
        bool support
    ) external {
        require(votingMembers[country], "Not CEFTA member");
        require(!voted[proposalId][country], "Already voted");
        voted[proposalId][country] = true;
        if (support) proposals[proposalId].yesVotes++;
        else proposals[proposalId].noVotes++;
        //proverimo da li je broj glasova jednak broju membera
        //ako jeste
        emit VoteCast(proposalId, country, support);
        //p.executed = true;
        //emit ProposalExecuted(proposalId);
    }

    //brises
    function _execute(uint256 proposalId) internal {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(p.yesVotes > p.noVotes, "Majority not reached");
        p.executed = true;
        emit ProposalExecuted(proposalId);
    }
}

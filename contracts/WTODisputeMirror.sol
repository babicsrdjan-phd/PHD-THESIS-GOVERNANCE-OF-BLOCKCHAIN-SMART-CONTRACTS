// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WTODisputeMirror
 * @notice Mirrors WTO DSU procedural stages on-chain for
 *         multilateral compliance tracking.
 */
contract WTODisputeMirror is Ownable {

    enum Stage {
        Consultation,
        PanelEstablished,
        PanelReportIssued,
        ComplianceReview,
        Closed
    }

    struct Dispute {
        string complainant;
        string respondent;
        string measure;
        Stage  stage;
        string panelFinding;
        bool   violation;
    }

    uint256 public disputeCount;
    mapping(uint256 => Dispute) public disputes;

    event DisputeRegistered(uint256 id, string complainant,
                            string respondent);
    event DisputeUpdated(uint256 id, Stage stage);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function registerDispute(
        string memory complainant, string memory respondent,
        string memory measure
    ) external onlyOwner {
        disputes[disputeCount] = Dispute(
            complainant, respondent, measure,
            Stage.Consultation, "", false
        );
        emit DisputeRegistered(disputeCount, complainant, respondent);
        disputeCount++;
    }

    function updateStage(uint256 id, Stage stage) external onlyOwner {
        disputes[id].stage = stage;
        emit DisputeUpdated(id, stage);
    }

    function recordPanelFinding(
        uint256 id, string memory finding, bool violation
    ) external onlyOwner {
        disputes[id].panelFinding = finding;
        disputes[id].violation = violation;
        disputes[id].stage = Stage.PanelReportIssued;
        emit DisputeUpdated(id, Stage.PanelReportIssued);
    }
}

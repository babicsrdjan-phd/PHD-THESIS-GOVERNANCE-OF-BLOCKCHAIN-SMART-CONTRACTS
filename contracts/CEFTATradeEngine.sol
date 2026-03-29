// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CEFTATradeEngine
 * @notice Consolidated trade execution engine implementing the
 *         complete CEFTA/WTO governance validation pipeline.
 * @dev    Orchestrates CEFTAMembershipRegistry, TariffQuotaRegistry,
 *         OriginProtocolRegistry, and WTOComplianceRegistry.
 */

// --- Interface declarations ---
interface IMembership {
    function verifyMember(string memory) external view returns (bool);
}

interface ITariff {
    function checkQuota(
        string memory,
        string memory,
        uint256
    ) external view returns (bool, uint256);

    function consumeQuota(string memory, string memory, uint256) external;
}

interface IOrigin {
    function verifyOrigin(bytes32) external view returns (bool);
}

interface IWTO {
    function verifyAlignment() external view returns (bool);
}

contract CEFTATradeEngine is Ownable {
    IMembership public membership;
    ITariff public tariffQuota;
    IOrigin public origin;
    IWTO public wto;

    event TradeExecuted(
        string exporter,
        string importer,
        string hsCode,
        uint256 quantity,
        uint256 dutyPaid
    );

    constructor(
        address initialOwner,
        address _membership,
        address _tariff,
        address _origin,
        address _wto
    ) Ownable(initialOwner) {
        membership = IMembership(_membership);
        tariffQuota = ITariff(_tariff);
        origin = IOrigin(_origin);
        wto = IWTO(_wto);
    }

    /**
     * @notice Execute a CEFTA trade transaction with full
     *         governance validation.
     * @param  exporter     Exporting country name
     * @param  importer     Importing country name
     * @param  hsCode       Harmonized System code (e.g., "040610")
     * @param  quantity     Quantity in tonnes
     * @param  invoiceValue Invoice value for duty calculation
     * @param  certHash     Hash of origin certificate
     */
    function executeTrade(
        string memory exporter,
        string memory importer,
        string memory hsCode,
        uint256 quantity,
        uint256 invoiceValue,
        bytes32 certHash
    ) external payable {
        // Step 1: WTO Alignment (CEFTA Preamble)
        require(wto.verifyAlignment(), "Not WTO compliant");

        // Step 2: Membership Verification (CEFTA Art. 1)
        require(membership.verifyMember(exporter), "Exporter not CEFTA member");
        require(membership.verifyMember(importer), "Importer not CEFTA member");

        // Step 3: HS Code Validation (Annex 1)
        require(
            keccak256(bytes(hsCode)) == keccak256(bytes("040610")),
            "Unsupported HS Code"
        );

        // Step 4: Quota & Duty Logic (Annex 3)
        (bool quotaAvailable, uint256 dutyRate) = tariffQuota.checkQuota(
            importer,
            hsCode,
            quantity
        );

        uint256 dutyRequired = 0;
        if (!quotaAvailable) {
            dutyRequired = (invoiceValue * dutyRate) / 100;
            require(msg.value >= dutyRequired, "Duty payment insufficient");
        }

        // Step 5: Origin Verification (Annex 4)
        require(origin.verifyOrigin(certHash), "Invalid proof of origin");

        // Step 6: Consume Quota
        tariffQuota.consumeQuota(importer, hsCode, quantity);

        // Step 7: Emit Audit Event
        emit TradeExecuted(exporter, importer, hsCode, quantity, dutyRequired);
    }
}

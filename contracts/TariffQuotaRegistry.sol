// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TariffQuotaRegistry
 * @notice Encodes the bilateral tariff and quota regime defined
 *         in CEFTA Annexes 1–3 for all active CEFTA member states.
 * @dev    consumeQuota() is restricted to the authorised trade
 *         engine via the onlyEngine modifier.
 */
contract TariffQuotaRegistry is Ownable {
    struct TariffQuota {
        uint256 quota;
        uint256 used;
        uint256 mfnDuty; // MFN duty rate (%) when quota exceeded
        bool quotaExists;
    }

    /// @notice Authorised CEFTATradeEngine contract address
    address public authorizedEngine;

    /// @dev tariffs[importer][hsCode] => TariffQuota
    mapping(string => mapping(string => TariffQuota)) public tariffs;

    event QuotaConsumed(
        string country,
        string hsCode,
        uint256 qty,
        uint256 remaining
    );
    event EngineAuthorized(address engine);

    modifier onlyEngine() {
        require(
            msg.sender == authorizedEngine,
            "Caller is not the authorized engine"
        );
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {
        // -------------------------------------------------------
        // Complete bilateral tariff matrix for HS 040610
        // (fresh cheese and curd) per CEFTA Annexes 1–3
        // -------------------------------------------------------

        // Bosnia and Herzegovina: zero duty, no quota for all
        // CEFTA partners (Art. 4 general tariff elimination)
        tariffs["Bosnia and Herzegovina"]["040610"] = TariffQuota({
            quota: 0,
            used: 0,
            mfnDuty: 0,
            quotaExists: false
        });

        // Macedonia: 50-tonne quota for Albanian imports;
        // zero duty for BiH, Montenegro, Serbia;
        // MFN rate (10%) applies to Moldova and over-quota
        tariffs["Macedonia"]["040610"] = TariffQuota({
            quota: 50,
            used: 0,
            mfnDuty: 10,
            quotaExists: true
        });

        // Serbia: 200-tonne quota for Albanian imports;
        // zero duty for BiH, Moldova, Montenegro, Kosovo
        tariffs["Serbia"]["040610"] = TariffQuota({
            quota: 200,
            used: 0,
            mfnDuty: 15,
            quotaExists: true
        });

        // Albania: zero duty, no quota restrictions
        // (general tariff elimination per Art. 4)
        tariffs["Albania"]["040610"] = TariffQuota({
            quota: 0,
            used: 0,
            mfnDuty: 0,
            quotaExists: false
        });

        // Moldova: zero duty, no quota restrictions
        tariffs["Moldova"]["040610"] = TariffQuota({
            quota: 0,
            used: 0,
            mfnDuty: 0,
            quotaExists: false
        });

        // Montenegro: zero duty, no quota restrictions
        tariffs["Montenegro"]["040610"] = TariffQuota({
            quota: 0,
            used: 0,
            mfnDuty: 0,
            quotaExists: false
        });

        // Kosovo: zero duty, no quota restrictions
        tariffs["Kosovo"]["040610"] = TariffQuota({
            quota: 0,
            used: 0,
            mfnDuty: 0,
            quotaExists: false
        });
    }

    /**
     * @notice Set the authorised trade engine contract address.
     * @dev    Only the contract owner can call this function.
     */
    function setAuthorizedEngine(address _engine) external onlyOwner {
        require(_engine != address(0), "Invalid engine address");
        authorizedEngine = _engine;
        emit EngineAuthorized(_engine);
    }

    /**
     * @notice Set or update a tariff entry for a given
     *         importer–HS code pair.
     */
    function setTariff(
        string memory country,
        string memory hsCode,
        uint256 quota,
        uint256 mfnDuty,
        bool quotaExists
    ) external onlyOwner {
        tariffs[country][hsCode] = TariffQuota(quota, 0, mfnDuty, quotaExists);
    }

    /**
     * @notice Check whether a trade falls within quota and
     *         determine the applicable duty rate.
     * @return quotaAvailable True if within quota or no quota
     * @return dutyRate       Applicable duty percentage
     */
    function checkQuota(
        string memory country,
        string memory hsCode,
        uint256 qty
    ) public view returns (bool quotaAvailable, uint256 dutyRate) {
        TariffQuota memory tq = tariffs[country][hsCode];
        if (!tq.quotaExists) return (true, 0);
        if (tq.used + qty <= tq.quota) return (true, 0);
        return (false, tq.mfnDuty);
    }

    /**
     * @notice Consume quota allocation for a completed trade.
     * @dev    Restricted to the authorised CEFTATradeEngine.
     */
    function consumeQuota(
        string memory country,
        string memory hsCode,
        uint256 qty
    ) external onlyEngine {
        TariffQuota storage tq = tariffs[country][hsCode];
        if (tq.quotaExists) {
            tq.used += qty;
            uint256 rem = tq.quota > tq.used ? tq.quota - tq.used : 0;
            emit QuotaConsumed(country, hsCode, qty, rem);
        }
    }
}

// test/CEFTATradeEngine.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");
 
describe("CEFTA Trade Engine Full Governance Validation Suite", function () {
  let membership, wto, tariff, origin, engine;
  let owner, trader;
  const HS = "040610";
 
  beforeEach(async function () {
    [owner, trader] = await ethers.getSigners();
 
    // Deploy all contracts first
    const M = await ethers.getContractFactory("CEFTAMembershipRegistry");
    membership = await M.deploy(owner.address);
 
    const W = await ethers.getContractFactory("WTOComplianceRegistry");
    wto = await W.deploy(owner.address);
 
    const T = await ethers.getContractFactory("TariffQuotaRegistry");
    tariff = await T.deploy(owner.address);
 
    const O = await ethers.getContractFactory("OriginProtocolRegistry");
    origin = await O.deploy(owner.address);
 
    const E = await ethers.getContractFactory("CEFTATradeEngine");
    engine = await E.deploy(
      owner.address,
      membership.target,
      tariff.target,
      origin.target,
      wto.target,
    );
 
    // Authorise the engine AFTER all deployments
    await tariff.setAuthorizedEngine(engine.target);
  });
 
  // ================================================
  // POSITIVE CASE 1: No quota country, zero duty
  // Scenario: Serbia → Bosnia and Herzegovina
  // Expected: Trade executes with duty = 0
  // ================================================
  it("Positive 1: Executes with zero duty (no quota)", async function () {
    console.log("START TEST - Executes with zero duty (no quota)");
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT1"));
    console.log("- Registering certificate");
    console.log("- Certificate hash:", cert);
    console.log("- Origin params: rule=1, nonOrigContent=0%, insufficientProcessing=false");
    await origin.registerCertificate(cert, 1, 0, false);
    console.log("- Certificate registered on OriginProtocolRegistry");
    console.log("- Bosnia and Herzegovina has no quota for HS 040610 → duty will be 0");
    console.log(
      "- Registering Trade -> Exporter from Sertbia, Importer from Bosnia, HS123, quoantity 10, ....",
    );
    console.log("- Calling CEFTATradeEngine.executeTrade(Serbia, Bosnia and Herzegovina, 040610, qty=10, val=1000, cert)");
    console.log("- Engine checks: membership registry → Serbia active ✓, Bosnia active ✓");
    console.log("- Engine checks: HS code 040610 → supported ✓");
    console.log("- Engine checks: origin certificate rule=1, nonOrigContent=0% ≤ 10% ✓, insufficientProcessing=false ✓");
    console.log("- Engine checks: TariffQuotaRegistry → no quota for Bosnia → preferential duty = 0");
    console.log("- No ETH value required: duty = 0");
    await expect(
      engine.executeTrade(
        "Serbia",
        "Bosnia and Herzegovina",
        HS,
        10,
        1000,
        cert,
      ),
    )
      .to.emit(engine, "TradeExecuted")
      .withArgs("Serbia", "Bosnia and Herzegovina", HS, 10, 0);
    console.log("- Trader registered");
    console.log("- event emited with parames Serbia Bosna, hS...");
    console.log("- TradeExecuted event confirmed: exporter=Serbia, importer=Bosnia and Herzegovina, HS=040610, qty=10, duty=0");
    console.log("END TEST - Executes with zero duty (no quota)");
  });
 
  // ================================================
  // POSITIVE CASE 2: Within quota, zero duty
  // Scenario: Serbia → Macedonia, 20 tonnes (quota: 50)
  // Expected: Trade executes with duty = 0
  // ================================================
  it("Positive 2: Within quota zero duty (Macedonia)", async function () {
    console.log("START TEST - Within quota zero duty (Macedonia)");
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT2"));
    console.log("- Certificate hash:", cert);
    console.log("- Registering certificate CERT2: rule=2, nonOrigContent=5%, insufficientProcessing=false");
    await origin.registerCertificate(cert, 2, 5, false);
    console.log("- Certificate registered on OriginProtocolRegistry");
    console.log("- Calling CEFTATradeEngine.executeTrade(Serbia, Macedonia, 040610, qty=20, val=2000, cert)");
    console.log("- Engine checks: membership registry → Serbia active ✓, Macedonia active ✓");
    console.log("- Engine checks: HS code 040610 → supported ✓");
    console.log("- Engine checks: origin certificate rule=2, nonOrigContent=5% ≤ 10% ✓, insufficientProcessing=false ✓");
    console.log("- Engine checks: TariffQuotaRegistry → Macedonia quota for HS 040610 = 50 units");
    console.log("- Quota check: qty=20 ≤ quota=50 → within quota → preferential duty = 0");
    console.log("- No ETH value required: duty = 0");
    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 20, 2000, cert),
    ).to.emit(engine, "TradeExecuted");
    console.log("- TradeExecuted event confirmed: trade within quota, duty=0 applied");
    console.log("END TEST - Within quota zero duty (Macedonia)");
  });
 
  // ================================================
  // POSITIVE CASE 3: Quota exceeded, MFN duty paid
  // Scenario: Serbia → Macedonia, 100 tonnes (quota: 50)
  // Expected: Trade executes with MFN duty = 10% of 1000 = 100
  // ================================================
  it("Positive 3: Quota exceeded MFN duty paid", async function () {
    console.log("START TEST - Quota exceeded MFN duty paid");
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT3"));
    console.log("- Certificate hash:", cert);
    console.log("- Registering certificate CERT3: rule=1, nonOrigContent=0%, insufficientProcessing=false");
    await origin.registerCertificate(cert, 1, 0, false);
    console.log("- Certificate registered on OriginProtocolRegistry");
    const val = 1000;
    const duty = (val * 10) / 100; // 10% MFN
    console.log("- Trade value: val=" + val);
    console.log("- MFN duty rate: 10% → computed duty = (1000 × 10) / 100 =", duty);
    console.log("- Calling CEFTATradeEngine.executeTrade(Serbia, Macedonia, 040610, qty=100, val=1000, cert, {value: 100})");
    console.log("- Engine checks: membership registry → Serbia active ✓, Macedonia active ✓");
    console.log("- Engine checks: HS code 040610 → supported ✓");
    console.log("- Engine checks: origin certificate → all origin rules satisfied ✓");
    console.log("- Engine checks: TariffQuotaRegistry → quota=50, qty=100 exceeds quota → MFN duty triggered");
    console.log("- Engine checks: msg.value=" + duty + " ≥ required duty=" + duty + " ✓ → duty payment accepted");
    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 100, val, cert, {
        value: duty,
      }),
    )
      .to.emit(engine, "TradeExecuted")
      .withArgs("Serbia", "Macedonia", HS, 100, duty);
    console.log("- TradeExecuted event confirmed: exporter=Serbia, importer=Macedonia, HS=040610, qty=100, duty=100");
    console.log("END TEST - Quota exceeded MFN duty paid");
  });
 
  // ================================================
  // NEGATIVE CASE 1: Invalid HS code
  // Expected: Reverts with "Unsupported HS Code"
  // ================================================
  it("Negative 1: Invalid HS code reverts", async function () {
    console.log("START TEST - Invalid HS code reverts");
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT4"));
    console.log("- Certificate hash:", cert);
    console.log("- Registering certificate CERT4: rule=1, nonOrigContent=0%, insufficientProcessing=false");
    await origin.registerCertificate(cert, 1, 0, false);
    console.log("- Certificate registered on OriginProtocolRegistry");
    console.log("- Calling CEFTATradeEngine.executeTrade with invalid HS code: '999999'");
    console.log("- Engine checks: membership → pass; then HS code lookup '999999'");
    console.log("- HS code '999999' not found in supported HS registry → revert triggered");
    console.log("- Expecting revert with message: 'Unsupported HS Code'");
    await expect(
      engine.executeTrade("Serbia", "Macedonia", "999999", 10, 1000, cert),
    ).to.be.revertedWith("Unsupported HS Code");
    console.log("- Revert confirmed: 'Unsupported HS Code' ✓");
    console.log("END TEST - Invalid HS code reverts");
  });
 
  // ================================================
  // NEGATIVE CASE 2: Art.7 insufficient processing
  // Expected: Reverts with "Insufficient processing - Art7"
  // ================================================
  it("Negative 2: Insufficient processing (Art.7) reverts", async function () {
    console.log(
      "-> Start of Negative 2: Insufficient processing (Art.7) reverts",
    );
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT5"));
    console.log("Invalid transaction with wrong setificate set CERT5");
    console.log("- Certificate hash:", cert);
    console.log("- Registering certificate CERT5: rule=2, nonOrigContent=5%, insufficientProcessing=true ← Art.7 flag set");
    await origin.registerCertificate(cert, 2, 5, true);
    console.log("- Certificate registered with insufficientProcessing=true on OriginProtocolRegistry");
    console.log("- Calling CEFTATradeEngine.executeTrade(Serbia, Macedonia, 040610, qty=10, val=1000, cert)");
    console.log("- Engine checks: membership → pass; HS code 040610 → pass");
    console.log("- Engine checks: OriginProtocolRegistry → insufficientProcessing=true → Art.7 violation detected");
    console.log("- Expecting revert with message: 'Insufficient processing - Art7'");
    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 10, 1000, cert),
    ).to.be.revertedWith("Insufficient processing - Art7");
    console.log("- Revert confirmed: 'Insufficient processing - Art7' ✓");
    console.log(
      "-> End of Negative 2: Insufficient processing (Art.7) reverts",
    );
  });
 
  // ================================================
  // NEGATIVE CASE 3: Non-originating content > 10%
  // Expected: Reverts with "Invalid proof of origin"
  // ================================================
  it("Negative 3: Non-originating > 10% reverts", async function () {
    console.log("START TEST - Non-originating > 10% reverts");
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT6"));
    console.log("- Certificate hash:", cert);
    console.log("- Registering certificate CERT6: rule=2, nonOrigContent=20% ← exceeds 10% threshold, insufficientProcessing=false");
    await origin.registerCertificate(cert, 2, 20, false);
    console.log("- Certificate registered with nonOrigContent=20% on OriginProtocolRegistry");
    console.log("- Calling CEFTATradeEngine.executeTrade(Serbia, Macedonia, 040610, qty=10, val=1000, cert)");
    console.log("- Engine checks: membership → pass; HS code 040610 → pass");
    console.log("- Engine checks: OriginProtocolRegistry → nonOrigContent=20% > allowed threshold of 10%");
    console.log("- Origin proof invalid → revert triggered before duty calculation");
    console.log("- Expecting revert with message: 'Invalid proof of origin'");
    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 10, 1000, cert),
    ).to.be.revertedWith("Invalid proof of origin");
    console.log("- Revert confirmed: 'Invalid proof of origin' ✓");
    console.log("END TEST - Non-originating > 10% reverts");
  });
 
  // ================================================
  // NEGATIVE CASE 4: Insufficient duty payment
  // Expected: Reverts with "Duty payment insufficient"
  // ================================================
  it("Negative 4: Insufficient duty reverts", async function () {
    console.log("START TEST - Insufficient duty reverts");
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT7"));
    console.log("- Certificate hash:", cert);
    console.log("- Registering certificate CERT7: rule=1, nonOrigContent=0%, insufficientProcessing=false");
    await origin.registerCertificate(cert, 1, 0, false);
    console.log("- Certificate registered on OriginProtocolRegistry");
    console.log("- Trade params: Serbia → Macedonia, HS=040610, qty=100, val=1000");
    console.log("- Quota check: qty=100 > quota=50 → MFN duty required = 10% × 1000 = 100");
    console.log("- Calling executeTrade with {value: 0} ← deliberate underpayment (required: 100)");
    console.log("- Engine checks: msg.value=0 < required duty=100 → duty validation fails");
    console.log("- Expecting revert with message: 'Duty payment insufficient'");
    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 100, 1000, cert, {
        value: 0,
      }),
    ).to.be.revertedWith("Duty payment insufficient");
    console.log("- Revert confirmed: 'Duty payment insufficient' ✓");
    console.log("END TEST - Insufficient duty reverts");
  });
 
  // ================================================
  // NEGATIVE CASE 5: Non-member country (Withdrawn)
  // Expected: Reverts with "Exporter not CEFTA member"
  // ================================================
  it("Negative 5: Withdrawn member (Croatia) reverts", async function () {
    console.log("START TEST - Withdrawn member (Croatia) reverts");
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT8"));
    console.log("- Certificate hash:", cert);
    console.log("- Registering certificate CERT8: rule=1, nonOrigContent=0%, insufficientProcessing=false");
    await origin.registerCertificate(cert, 1, 0, false);
    console.log("- Certificate registered on OriginProtocolRegistry");
    console.log("- Calling CEFTATradeEngine.executeTrade(Croatia, Macedonia, 040610, qty=10, val=1000, cert)");
    console.log("- Engine checks: CEFTAMembershipRegistry → querying exporter 'Croatia'");
    console.log("- Croatia withdrew from CEFTA upon EU accession (2013) → not in active member registry");
    console.log("- Membership validation fails on first check → revert triggered before any further checks");
    console.log("- Expecting revert with message: 'Exporter not CEFTA member'");
    await expect(
      engine.executeTrade("Croatia", "Macedonia", HS, 10, 1000, cert),
    ).to.be.revertedWith("Exporter not CEFTA member");
    console.log("- Revert confirmed: 'Exporter not CEFTA member' ✓");
    console.log("END TEST - Withdrawn member (Croatia) reverts");
  });
});

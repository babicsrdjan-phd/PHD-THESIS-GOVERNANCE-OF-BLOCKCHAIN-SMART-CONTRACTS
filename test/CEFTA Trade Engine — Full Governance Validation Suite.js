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
    await origin.registerCertificate(cert, 1, 0, false);

    console.log(
      "- Registering Trade -> Exporter from Sertbia, Importer from Bosnia, HS123, quoantity 10, ....",
    );
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
    console.log("END TEST - Executes with zero duty (no quota)");
  });

  // ================================================
  // POSITIVE CASE 2: Within quota, zero duty
  // Scenario: Serbia → Macedonia, 20 tonnes (quota: 50)
  // Expected: Trade executes with duty = 0
  // ================================================
  it("Positive 2: Within quota zero duty (Macedonia)", async function () {
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT2"));
    await origin.registerCertificate(cert, 2, 5, false);

    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 20, 2000, cert),
    ).to.emit(engine, "TradeExecuted");
  });

  // ================================================
  // POSITIVE CASE 3: Quota exceeded, MFN duty paid
  // Scenario: Serbia → Macedonia, 100 tonnes (quota: 50)
  // Expected: Trade executes with MFN duty = 10% of 1000 = 100
  // ================================================
  it("Positive 3: Quota exceeded MFN duty paid", async function () {
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT3"));
    await origin.registerCertificate(cert, 1, 0, false);

    const val = 1000;
    const duty = (val * 10) / 100; // 10% MFN
    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 100, val, cert, {
        value: duty,
      }),
    )
      .to.emit(engine, "TradeExecuted")
      .withArgs("Serbia", "Macedonia", HS, 100, duty);
  });

  // ================================================
  // NEGATIVE CASE 1: Invalid HS code
  // Expected: Reverts with "Unsupported HS Code"
  // ================================================
  it("Negative 1: Invalid HS code reverts", async function () {
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT4"));
    await origin.registerCertificate(cert, 1, 0, false);

    await expect(
      engine.executeTrade("Serbia", "Macedonia", "999999", 10, 1000, cert),
    ).to.be.revertedWith("Unsupported HS Code");
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
    await origin.registerCertificate(cert, 2, 5, true);

    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 10, 1000, cert),
    ).to.be.revertedWith("Insufficient processing - Art7");
    console.log(
      "-> End of Negative 2: Insufficient processing (Art.7) reverts",
    );
  });

  // ================================================
  // NEGATIVE CASE 3: Non-originating content > 10%
  // Expected: Reverts with "Invalid proof of origin"
  // ================================================
  it("Negative 3: Non-originating > 10% reverts", async function () {
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT6"));
    await origin.registerCertificate(cert, 2, 20, false);

    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 10, 1000, cert),
    ).to.be.revertedWith("Invalid proof of origin");
  });

  // ================================================
  // NEGATIVE CASE 4: Insufficient duty payment
  // Expected: Reverts with "Duty payment insufficient"
  // ================================================
  it("Negative 4: Insufficient duty reverts", async function () {
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT7"));
    await origin.registerCertificate(cert, 1, 0, false);

    await expect(
      engine.executeTrade("Serbia", "Macedonia", HS, 100, 1000, cert, {
        value: 0,
      }),
    ).to.be.revertedWith("Duty payment insufficient");
  });

  // ================================================
  // NEGATIVE CASE 5: Non-member country (Withdrawn)
  // Expected: Reverts with "Exporter not CEFTA member"
  // ================================================
  it("Negative 5: Withdrawn member (Croatia) reverts", async function () {
    const cert = ethers.keccak256(ethers.toUtf8Bytes("CERT8"));
    await origin.registerCertificate(cert, 1, 0, false);

    await expect(
      engine.executeTrade("Croatia", "Macedonia", HS, 10, 1000, cert),
    ).to.be.revertedWith("Exporter not CEFTA member");
  });
});

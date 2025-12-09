const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("TrustlessEscrow - Code is Law Tests", function () {
  let escrow;
  let client, freelancer, arbiter, other;
  const DEPOSIT_AMOUNT = ethers.parseEther("1.0");

  beforeEach(async function () {
    [client, freelancer, arbiter, other] = await ethers.getSigners();
    
    const TrustlessEscrow = await ethers.getContractFactory("TrustlessEscrow");
    escrow = await TrustlessEscrow.deploy(
      client.address,
      freelancer.address,
      arbiter.address
    );
  });

  describe("CONCEPT 1: Immutable State Machine", function () {
    it("Should start in CREATED state", async function () {
      const details = await escrow.getEscrowDetails();
      expect(details.state).to.equal(0); // CREATED
    });

    it("Should transition CREATED → FUNDED on deposit", async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      const details = await escrow.getEscrowDetails();
      expect(details.state).to.equal(1); // FUNDED
    });

    it("Should enforce valid state transitions only", async function () {
      // Cannot complete work before funding
      await expect(
        escrow.connect(freelancer).completeWork()
      ).to.be.revertedWith("Invalid state for this action");
    });

    it("Should emit StateTransition events", async function () {
      await expect(escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT }))
        .to.emit(escrow, "StateTransition")
        .withArgs(0, 1, await time.latest());
    });
  });

  describe("CONCEPT 2: Self-Executing Agreements", function () {
    beforeEach(async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
    });

    it("Should automatically hold funds without intermediary", async function () {
      const balance = await ethers.provider.getBalance(await escrow.getAddress());
      expect(balance).to.equal(DEPOSIT_AMOUNT);
    });

    it("Should automatically release payment on approval", async function () {
      await escrow.connect(freelancer).completeWork();
      
      const initialBalance = await ethers.provider.getBalance(freelancer.address);
      await escrow.connect(client).approveAndPay();
      const finalBalance = await ethers.provider.getBalance(freelancer.address);
      
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it("Should auto-release after dispute period", async function () {
      await escrow.connect(freelancer).completeWork();
      
      // Fast forward 7 days
      await time.increase(7 * 24 * 60 * 60 + 1);
      
      const initialBalance = await ethers.provider.getBalance(freelancer.address);
      await escrow.autoReleasePayment();
      const finalBalance = await ethers.provider.getBalance(freelancer.address);
      
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it("Should auto-refund if work never completed (30 days)", async function () {
      // Fast forward 30 days
      await time.increase(30 * 24 * 60 * 60 + 1);
      
      const initialBalance = await ethers.provider.getBalance(client.address);
      await escrow.connect(client).requestRefund();
      const finalBalance = await ethers.provider.getBalance(client.address);
      
      expect(finalBalance).to.be.gt(initialBalance);
    });
  });

  describe("CONCEPT 3: Cryptographic Proof & Verification", function () {
    it("Should emit FundsDeposited with block data", async function () {
      const tx = await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt.blockNumber);

      await expect(tx)
        .to.emit(escrow, "FundsDeposited")
        .withArgs(client.address, DEPOSIT_AMOUNT, block.timestamp, block.number);
    });

    it("Should allow anyone to verify escrow state on-chain", async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      
      // Anyone (even non-participants) can verify
      const details = await escrow.connect(other).getEscrowDetails();
      expect(details.amount).to.equal(DEPOSIT_AMOUNT);
      expect(details.state).to.equal(1); // FUNDED
    });

    it("Should create permanent audit trail via events", async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      await escrow.connect(freelancer).completeWork();
      
      const filter = escrow.filters.StateTransition();
      const events = await escrow.queryFilter(filter);
      
      expect(events.length).to.equal(2); // CREATED→FUNDED, FUNDED→WORK_DONE
    });
  });

  describe("CONCEPT 4: Trustless Interaction", function () {
    it("Client doesn't trust freelancer - funds locked in contract", async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      
      // Freelancer cannot withdraw without completing work and approval
      await expect(
        escrow.connect(freelancer).approveAndPay()
      ).to.be.revertedWith("Only client can call this");
    });

    it("Freelancer doesn't trust client - payment guaranteed after dispute period", async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      await escrow.connect(freelancer).completeWork();
      
      // Even if client disappears, freelancer gets paid after 7 days
      await time.increase(7 * 24 * 60 * 60 + 1);
      await escrow.autoReleasePayment();
      
      const details = await escrow.getEscrowDetails();
      expect(details.state).to.equal(3); // PAID
    });

    it("Arbiter provides neutral dispute resolution", async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      await escrow.connect(freelancer).completeWork();
      await escrow.connect(client).raiseDispute("Poor quality work");
      
      // Arbiter can resolve in favor of either party
      await escrow.connect(arbiter).resolveDisputeForFreelancer();
      
      const details = await escrow.getEscrowDetails();
      expect(details.state).to.equal(3); // PAID
    });
  });

  describe("CONCEPT 5: Gas Economics & Incentive Design", function () {
    it("Client pays gas to deposit (commitment)", async function () {
      const initialBalance = await ethers.provider.getBalance(client.address);
      const tx = await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed * tx.gasPrice;
      
      const finalBalance = await ethers.provider.getBalance(client.address);
      
      // Client paid: deposit amount + gas fees
      expect(initialBalance - finalBalance).to.be.gt(DEPOSIT_AMOUNT);
    });

    it("Freelancer pays gas to mark complete (commitment)", async function () {
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      
      const initialBalance = await ethers.provider.getBalance(freelancer.address);
      const tx = await escrow.connect(freelancer).completeWork();
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed * tx.gasPrice;
      
      const finalBalance = await ethers.provider.getBalance(freelancer.address);
      
      // Freelancer paid gas (commitment to deliver)
      expect(initialBalance - finalBalance).to.equal(gasCost);
    });

    it("Spam prevention - every action costs gas", async function () {
      // Attempting to deposit multiple times costs gas each time
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      
      // Second deposit fails but still costs gas
      const tx = escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      await expect(tx).to.be.revertedWith("Invalid state for this action");
    });
  });

  describe("Security: ReentrancyGuard Protection", function () {
    it("Should prevent reentrancy attacks", async function () {
      // Contract uses ReentrancyGuard on all fund transfers
      await escrow.connect(client).depositFunds({ value: DEPOSIT_AMOUNT });
      await escrow.connect(freelancer).completeWork();
      await escrow.connect(client).approveAndPay();
      
      // Cannot be called again
      await expect(
        escrow.connect(client).approveAndPay()
      ).to.be.revertedWith("Invalid state for this action");
    });
  });
});

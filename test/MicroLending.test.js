const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MicroLending", function () {
  let microLending;
  let owner;
  let lender1;
  let lender2;
  let borrower1;

  beforeEach(async function () {
    [owner, lender1, lender2, borrower1] = await ethers.getSigners();

    const MicroLending = await ethers.getContractFactory("MicroLending");
    microLending = await MicroLending.deploy();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await microLending.owner()).to.equal(owner.address);
    });

    it("Should start with zero pool balance", async function () {
      expect(await microLending.totalPool()).to.equal(0);
    });
  });

  describe("Lending Pool", function () {
    it("Should allow deposits to pool", async function () {
      const depositAmount = ethers.parseEther("1.0");

      await expect(
        microLending.connect(lender1).depositToPool({ value: depositAmount })
      ).to.emit(microLending, "DepositMade")
        .withArgs(lender1.address, depositAmount);

      expect(await microLending.totalPool()).to.equal(depositAmount);
    });

    it("Should track lender balances", async function () {
      const depositAmount = ethers.parseEther("0.5");

      await microLending.connect(lender1).depositToPool({ value: depositAmount });

      const [deposited, withdrawn, available] = await microLending.getLenderInfo(lender1.address);
      expect(deposited).to.equal(depositAmount);
      expect(withdrawn).to.equal(0);
      expect(available).to.equal(depositAmount);
    });
  });

  describe("Loan Requests", function () {
    beforeEach(async function () {
      // Add funds to pool
      await microLending.connect(lender1).depositToPool({
        value: ethers.parseEther("2.0")
      });
    });

    it("Should allow valid loan requests", async function () {
      const loanAmount = ethers.parseEther("0.05");

      await expect(
        microLending.connect(borrower1).requestLoan(loanAmount)
      ).to.emit(microLending, "LoanRequested")
        .withArgs(1, borrower1.address, loanAmount);
    });

    it("Should reject loans outside limits", async function () {
      const tooSmall = ethers.parseEther("0.0005"); // Below min
      const tooBig = ethers.parseEther("0.2");       // Above max

      await expect(
        microLending.connect(borrower1).requestLoan(tooSmall)
      ).to.be.revertedWith("Invalid loan amount");

      await expect(
        microLending.connect(borrower1).requestLoan(tooBig)
      ).to.be.revertedWith("Invalid loan amount");
    });
  });

  describe("Loan Approval and Repayment", function () {
    beforeEach(async function () {
      // Setup: Add funds and request loan
      await microLending.connect(lender1).depositToPool({
        value: ethers.parseEther("1.0")
      });
      await microLending.connect(borrower1).requestLoan(
        ethers.parseEther("0.05")
      );
    });

    it("Should allow owner to approve loans", async function () {
      await expect(
        microLending.connect(owner).approveLoan(1)
      ).to.emit(microLending, "LoanApproved");

      const loanDetails = await microLending.getLoanDetails(1);
      expect(loanDetails[5]).to.be.true; // active field
    });

    it("Should transfer funds on approval", async function () {
      const initialBalance = await ethers.provider.getBalance(borrower1.address);

      await microLending.connect(owner).approveLoan(1);

      const finalBalance = await ethers.provider.getBalance(borrower1.address);
      expect(finalBalance - initialBalance).to.equal(ethers.parseEther("0.05"));
    });

    it("Should allow loan repayment", async function () {
      await microLending.connect(owner).approveLoan(1);

      const repaymentAmount = await microLending.calculateRepaymentAmount(1);

      await expect(
        microLending.connect(borrower1).repayLoan(1, { value: repaymentAmount })
      ).to.emit(microLending, "LoanRepaid");
    });
  });
});
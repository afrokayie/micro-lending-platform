const { ethers } = require("hardhat");

async function main() {
  // Replace with your deployed contract address
  const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; 
  
  const [owner, lender, borrower] = await ethers.getSigners();
  
  // Get contract instance
  const MicroLending = await ethers.getContractFactory("MicroLending");
  const microLending = MicroLending.attach(contractAddress);
  
  console.log("Contract deployed to:", contractAddress);
  console.log("Owner:", owner.address);
  
  // 1. Deposit to pool
  console.log("\n1. Depositing to pool...");
  const depositTx = await microLending.connect(lender).depositToPool({
    value: ethers.parseEther("0.1")
  });
  await depositTx.wait();
  
  const poolBalance = await microLending.totalPool();
  console.log("Pool balance:", ethers.formatEther(poolBalance), "ETH");
  
  // 2. Request loan
  console.log("\n2. Requesting loan...");
  const loanTx = await microLending.connect(borrower).requestLoan(
    ethers.parseEther("0.01")
  );
  await loanTx.wait();
  console.log("Loan requested!");
  
  // 3. Approve loan
  console.log("\n3. Approving loan...");
  const approveTx = await microLending.connect(owner).approveLoan(1);
  await approveTx.wait();
  console.log("Loan approved!");
  
  // 4. Check loan details
  const loanDetails = await microLending.getLoanDetails(1);
  console.log("Loan details:", {
    borrower: loanDetails[0],
    amount: ethers.formatEther(loanDetails[1]),
    active: loanDetails[5]
  });
  
  // 5. Calculate repayment
  const repaymentAmount = await microLending.calculateRepaymentAmount(1);
  console.log("Repayment amount:", ethers.formatEther(repaymentAmount), "ETH");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
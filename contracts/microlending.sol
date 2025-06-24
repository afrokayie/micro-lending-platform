// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MicroLending {
    address public owner;
    uint256 public totalPool;
    uint256 public nextLoanId = 1;
    
    // Interest rates in basis points (1000 = 10%)
    uint256 public constant STANDARD_INTEREST_RATE = 1000; // 10%
    uint256 public constant LOAN_DURATION = 30 days;
    uint256 public constant MIN_LOAN_AMOUNT = 0.001 ether; // 0.001 BTC equivalent
    uint256 public constant MAX_LOAN_AMOUNT = 0.1 ether;   // 0.1 BTC equivalent
    
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 dueDate;
        bool active;
        bool repaid;
        bool approved;
    }
    
    struct Lender {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 availableBalance;
    }
    
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => Lender) public lenders;
    mapping(address => bool) public hasActiveLoan;
    
    event LoanRequested(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanApproved(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 totalAmount);
    event DepositMade(address indexed lender, uint256 amount);
    event WithdrawalMade(address indexed lender, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validLoanAmount(uint256 amount) {
        require(amount >= MIN_LOAN_AMOUNT && amount <= MAX_LOAN_AMOUNT, "Invalid loan amount");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // Lenders deposit funds to the lending pool
    function depositToPool() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        totalPool += msg.value;
        lenders[msg.sender].totalDeposited += msg.value;
        lenders[msg.sender].availableBalance += msg.value;
        
        emit DepositMade(msg.sender, msg.value);
    }
    
    // Borrowers request a loan
    function requestLoan(uint256 amount) external validLoanAmount(amount) {
        require(!hasActiveLoan[msg.sender], "Borrower already has an active loan");
        require(amount <= totalPool, "Insufficient funds in pool");
        
        loans[nextLoanId] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: STANDARD_INTEREST_RATE,
            duration: LOAN_DURATION,
            startTime: 0, // Will be set when approved
            dueDate: 0,   // Will be set when approved
            active: false,
            repaid: false,
            approved: false
        });
        
        borrowerLoans[msg.sender].push(nextLoanId);
        
        emit LoanRequested(nextLoanId, msg.sender, amount);
        nextLoanId++;
    }
    
    // Owner approves a loan request
    function approveLoan(uint256 loanId) external onlyOwner {
        Loan storage loan = loans[loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(!loan.approved, "Loan already approved");
        require(!loan.active, "Loan already active");
        require(loan.amount <= totalPool, "Insufficient funds in pool");
        
        // Update loan status
        loan.approved = true;
        loan.active = true;
        loan.startTime = block.timestamp;
        loan.dueDate = block.timestamp + loan.duration;
        
        // Update pool and borrower status
        totalPool -= loan.amount;
        hasActiveLoan[loan.borrower] = true;
        
        // Transfer funds to borrower
        payable(loan.borrower).transfer(loan.amount);
        
        emit LoanApproved(loanId, loan.borrower, loan.amount);
    }
    
    // Borrower repays the loan
    function repayLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Only borrower can repay this loan");
        require(loan.active, "Loan is not active");
        require(!loan.repaid, "Loan already repaid");
        
        uint256 interestAmount = (loan.amount * loan.interestRate) / 10000;
        uint256 totalRepayment = loan.amount + interestAmount;
        
        require(msg.value >= totalRepayment, "Insufficient repayment amount");
        
        // Update loan status
        loan.repaid = true;
        loan.active = false;
        hasActiveLoan[msg.sender] = false;
        
        // Add repayment to pool (including interest)
        totalPool += totalRepayment;
        
        // Refund excess payment if any
        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }
        
        emit LoanRepaid(loanId, msg.sender, totalRepayment);
    }
    
    // Lenders withdraw their proportional share from the pool
    function withdrawFromPool(uint256 amount) external {
        Lender storage lender = lenders[msg.sender];
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(amount <= lender.availableBalance, "Insufficient balance");
        require(amount <= totalPool, "Insufficient funds in pool");
        
        // Calculate proportional share (simplified - in production, you'd want more sophisticated accounting)
        uint256 maxWithdrawal = (lender.totalDeposited * totalPool) / getTotalDeposited();
        require(amount <= maxWithdrawal, "Withdrawal exceeds proportional share");
        
        lender.availableBalance -= amount;
        lender.totalWithdrawn += amount;
        totalPool -= amount;
        
        payable(msg.sender).transfer(amount);
        
        emit WithdrawalMade(msg.sender, amount);
    }
    
    // View functions
    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 startTime,
        uint256 dueDate,
        bool active,
        bool repaid,
        bool approved
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.interestRate,
            loan.startTime,
            loan.dueDate,
            loan.active,
            loan.repaid,
            loan.approved
        );
    }
    
    function calculateRepaymentAmount(uint256 loanId) external view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 interestAmount = (loan.amount * loan.interestRate) / 10000;
        return loan.amount + interestAmount;
    }
    
    function getBorrowerLoans(address borrower) external view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }
    
    function getLenderInfo(address lender) external view returns (uint256 deposited, uint256 withdrawn, uint256 available) {
        Lender memory l = lenders[lender];
        return (l.totalDeposited, l.totalWithdrawn, l.availableBalance);
    }
    
    function isLoanOverdue(uint256 loanId) external view returns (bool) {
        Loan memory loan = loans[loanId];
        return loan.active && block.timestamp > loan.dueDate;
    }
    
    // Helper function to calculate total deposited (for proportional withdrawals)
    function getTotalDeposited() internal view returns (uint256) {
        // In a production contract, you'd track this more efficiently
        // For simplicity, we'll use a placeholder calculation
        return totalPool + getTotalWithdrawn();
    }
    
    function getTotalWithdrawn() internal pure returns (uint256) {
        // Placeholder - in production, track this as a state variable
        return 0;
    }
    
    // Emergency functions (only owner)
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
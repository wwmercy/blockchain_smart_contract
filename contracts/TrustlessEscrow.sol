// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TrustlessEscrow
 * @notice Pure smart contract escrow - Code is Law
 * @dev Implements immutable state machine with cryptographic verification
 */
contract TrustlessEscrow is ReentrancyGuard {
    
    // ==================== CONCEPT 1: IMMUTABLE STATE MACHINE ====================
    enum EscrowState { 
        CREATED,        // Initial state - escrow created
        FUNDED,         // Client deposited funds
        WORK_DONE,      // Freelancer marked work complete
        PAID,           // Payment released to freelancer
        REFUNDED,       // Payment returned to client
        DISPUTED        // Dispute initiated
    }
    
    // ==================== STATE VARIABLES ====================
    EscrowState public currentState;
    
    address payable public immutable client;
    address payable public immutable freelancer;
    address public immutable arbiter;
    
    uint256 public escrowAmount;
    uint256 public workCompletionTime;
    uint256 public createdAt;
    
    // Time-based automation constants
    uint256 public constant DISPUTE_PERIOD = 7 days;
    uint256 public constant AUTO_RELEASE_PERIOD = 30 days;
    
    // ==================== CONCEPT 3: CRYPTOGRAPHIC PROOF & VERIFICATION ====================
    // Events create permanent on-chain audit trail
    event EscrowCreated(
        address indexed client,
        address indexed freelancer,
        address indexed arbiter,
        uint256 timestamp,
        uint256 blockNumber
    );
    
    event FundsDeposited(
        address indexed from,
        uint256 amount,
        uint256 timestamp,
        uint256 blockNumber
    );
    
    event WorkCompleted(
        address indexed freelancer,
        uint256 timestamp,
        uint256 blockNumber
    );
    
    event PaymentReleased(
        address indexed to,
        uint256 amount,
        uint256 timestamp,
        uint256 blockNumber,
        bytes32 txHash
    );
    
    event PaymentRefunded(
        address indexed to,
        uint256 amount,
        uint256 timestamp,
        string reason
    );
    
    event DisputeRaised(
        address indexed by,
        uint256 timestamp,
        string reason
    );
    
    event StateTransition(
        EscrowState from,
        EscrowState to,
        uint256 timestamp
    );
    
    // ==================== MODIFIERS ====================
    modifier onlyClient() {
        require(msg.sender == client, "Only client can call this");
        _;
    }
    
    modifier onlyFreelancer() {
        require(msg.sender == freelancer, "Only freelancer can call this");
        _;
    }
    
    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter can call this");
        _;
    }
    
    modifier inState(EscrowState _state) {
        require(currentState == _state, "Invalid state for this action");
        _;
    }
    
    // ==================== CONSTRUCTOR ====================
    constructor(
        address payable _client,
        address payable _freelancer,
        address _arbiter
    ) {
        require(_client != address(0), "Invalid client address");
        require(_freelancer != address(0), "Invalid freelancer address");
        require(_arbiter != address(0), "Invalid arbiter address");
        require(_client != _freelancer, "Client and freelancer must be different");
        
        client = _client;
        freelancer = _freelancer;
        arbiter = _arbiter;
        currentState = EscrowState.CREATED;
        createdAt = block.timestamp;
        
        emit EscrowCreated(_client, _freelancer, _arbiter, block.timestamp, block.number);
    }
    
    // ==================== CONCEPT 2: SELF-EXECUTING AGREEMENTS ====================
    
    /**
     * @notice Client deposits funds into escrow
     * @dev Automatically transitions state and locks funds
     */
    function depositFunds() 
        external 
        payable 
        onlyClient 
        inState(EscrowState.CREATED) 
        nonReentrant 
    {
        require(msg.value > 0, "Must deposit funds");
        
        escrowAmount = msg.value;
        _transitionState(EscrowState.FUNDED);
        
        emit FundsDeposited(msg.sender, msg.value, block.timestamp, block.number);
    }
    
    /**
     * @notice Freelancer marks work as complete
     * @dev Starts dispute period timer
     */
    function completeWork() 
        external 
        onlyFreelancer 
        inState(EscrowState.FUNDED) 
    {
        workCompletionTime = block.timestamp;
        _transitionState(EscrowState.WORK_DONE);
        
        emit WorkCompleted(msg.sender, block.timestamp, block.number);
    }
    
    /**
     * @notice Client approves work and releases payment
     * @dev Automatically transfers funds to freelancer
     */
    function approveAndPay() 
        external 
        onlyClient 
        inState(EscrowState.WORK_DONE) 
        nonReentrant 
    {
        uint256 amount = escrowAmount;
        _transitionState(EscrowState.PAID);
        
        (bool success, ) = freelancer.call{value: amount}("");
        require(success, "Payment transfer failed");
        
        emit PaymentReleased(
            freelancer, 
            amount, 
            block.timestamp, 
            block.number,
            blockhash(block.number - 1)
        );
    }
    
    /**
     * @notice Auto-release payment after dispute period expires
     * @dev CONCEPT 2: Self-executing - no human intervention needed
     */
    function autoReleasePayment() 
        external 
        inState(EscrowState.WORK_DONE) 
        nonReentrant 
    {
        require(
            block.timestamp >= workCompletionTime + DISPUTE_PERIOD,
            "Dispute period still active"
        );
        
        uint256 amount = escrowAmount;
        _transitionState(EscrowState.PAID);
        
        (bool success, ) = freelancer.call{value: amount}("");
        require(success, "Payment transfer failed");
        
        emit PaymentReleased(
            freelancer, 
            amount, 
            block.timestamp, 
            block.number,
            blockhash(block.number - 1)
        );
    }
    
    // ==================== CONCEPT 4: TRUSTLESS INTERACTION ====================
    
    /**
     * @notice Client disputes the work quality
     * @dev Freezes funds until arbiter resolves
     */
    function raiseDispute(string calldata reason) 
        external 
        onlyClient 
        inState(EscrowState.WORK_DONE) 
    {
        require(
            block.timestamp <= workCompletionTime + DISPUTE_PERIOD,
            "Dispute period expired"
        );
        
        _transitionState(EscrowState.DISPUTED);
        emit DisputeRaised(msg.sender, block.timestamp, reason);
    }
    
    /**
     * @notice Arbiter resolves dispute in favor of freelancer
     */
    function resolveDisputeForFreelancer() 
        external 
        onlyArbiter 
        inState(EscrowState.DISPUTED) 
        nonReentrant 
    {
        uint256 amount = escrowAmount;
        _transitionState(EscrowState.PAID);
        
        (bool success, ) = freelancer.call{value: amount}("");
        require(success, "Payment transfer failed");
        
        emit PaymentReleased(
            freelancer, 
            amount, 
            block.timestamp, 
            block.number,
            blockhash(block.number - 1)
        );
    }
    
    /**
     * @notice Arbiter resolves dispute in favor of client
     */
    function resolveDisputeForClient() 
        external 
        onlyArbiter 
        inState(EscrowState.DISPUTED) 
        nonReentrant 
    {
        uint256 amount = escrowAmount;
        _transitionState(EscrowState.REFUNDED);
        
        (bool success, ) = client.call{value: amount}("");
        require(success, "Refund transfer failed");
        
        emit PaymentRefunded(client, amount, block.timestamp, "Dispute resolved for client");
    }
    
    /**
     * @notice Emergency refund if freelancer never completes work
     */
    function requestRefund() 
        external 
        onlyClient 
        inState(EscrowState.FUNDED) 
        nonReentrant 
    {
        require(
            block.timestamp >= createdAt + AUTO_RELEASE_PERIOD,
            "Must wait 30 days for auto-refund"
        );
        
        uint256 amount = escrowAmount;
        _transitionState(EscrowState.REFUNDED);
        
        (bool success, ) = client.call{value: amount}("");
        require(success, "Refund transfer failed");
        
        emit PaymentRefunded(client, amount, block.timestamp, "Auto-refund: work never completed");
    }
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    /**
     * @notice Internal state transition with event logging
     * @dev CONCEPT 1: Enforces valid state transitions only
     */
    function _transitionState(EscrowState _newState) internal {
        EscrowState oldState = currentState;
        currentState = _newState;
        emit StateTransition(oldState, _newState, block.timestamp);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @notice Get complete escrow details
     * @dev CONCEPT 3: Public verifiability - anyone can audit
     */
    function getEscrowDetails() external view returns (
        EscrowState state,
        address clientAddr,
        address freelancerAddr,
        address arbiterAddr,
        uint256 amount,
        uint256 created,
        uint256 workDoneTime,
        uint256 disputeDeadline
    ) {
        return (
            currentState,
            client,
            freelancer,
            arbiter,
            escrowAmount,
            createdAt,
            workCompletionTime,
            workCompletionTime > 0 ? workCompletionTime + DISPUTE_PERIOD : 0
        );
    }
    
    /**
     * @notice Check if dispute period is active
     */
    function isDisputePeriodActive() external view returns (bool) {
        if (currentState != EscrowState.WORK_DONE) return false;
        return block.timestamp <= workCompletionTime + DISPUTE_PERIOD;
    }
    
    /**
     * @notice Time remaining until auto-release
     */
    function timeUntilAutoRelease() external view returns (uint256) {
        if (currentState != EscrowState.WORK_DONE) return 0;
        
        uint256 releaseTime = workCompletionTime + DISPUTE_PERIOD;
        if (block.timestamp >= releaseTime) return 0;
        
        return releaseTime - block.timestamp;
    }
    
    // ==================== CONCEPT 5: GAS ECONOMICS ====================
    // Each function caller pays gas - creates skin in the game
    // Client pays gas for deposit/approve (commitment to hire)
    // Freelancer pays gas for completeWork (commitment to deliver)
    // Spam prevention: every action costs real money in gas fees
}

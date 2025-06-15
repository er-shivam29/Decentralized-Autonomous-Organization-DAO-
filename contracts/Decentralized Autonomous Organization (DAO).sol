// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Autonomous Organization (DAO)
 * @dev A smart contract that enables decentralized governance through token-based voting
 */
contract DAO {
    // State variables
    address public owner;
    uint256 public totalSupply;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    
    // Mappings
    mapping(address => uint256) public balances;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public votes;
    
    // Structs
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        address targetContract;
        bytes callData;
    }
    
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    
    // Modifiers
    modifier onlyTokenHolder() {
        require(balances[msg.sender] > 0, "Must hold tokens to participate");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        totalSupply = 0;
        proposalCount = 0;
    }
    
    /**
     * @dev Core Function 1: Mint governance tokens to participants
     * @param _to Address to mint tokens to
     * @param _amount Amount of tokens to mint
     */
    function mintTokens(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Cannot mint to zero address");
        require(_amount > 0, "Amount must be greater than zero");
        
        balances[_to] += _amount;
        totalSupply += _amount;
        
        emit TokensMinted(_to, _amount);
    }
    
    /**
     * @dev Core Function 2: Create a new proposal for voting
     * @param _description Description of the proposal
     * @param _targetContract Address of contract to call (use address(0) for governance-only proposals)
     * @param _callData Encoded function call data (empty for governance-only proposals)
     */
    function createProposal(
        string memory _description,
        address _targetContract,
        bytes memory _callData
    ) external onlyTokenHolder returns (uint256) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(balances[msg.sender] >= 100, "Need minimum 100 tokens to create proposal");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: _description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            executed: false,
            passed: false,
            targetContract: _targetContract,
            callData: _callData
        });
        
        emit ProposalCreated(proposalId, msg.sender, _description);
        return proposalId;
    }
    
    /**
     * @dev Core Function 3: Vote on a proposal
     * @param _proposalId ID of the proposal to vote on
     * @param _support True for yes, false for no
     */
    function vote(uint256 _proposalId, bool _support) external onlyTokenHolder validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted on this proposal");
        
        uint256 voterWeight = balances[msg.sender];
        hasVoted[_proposalId][msg.sender] = true;
        votes[_proposalId][msg.sender] = voterWeight;
        
        if (_support) {
            proposal.forVotes += voterWeight;
        } else {
            proposal.againstVotes += voterWeight;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support, voterWeight);
    }
    
    /**
     * @dev Execute a proposal after voting period ends
     * @param _proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp >= proposal.endTime + EXECUTION_DELAY, "Execution delay not met");
        
        proposal.executed = true;
        
        // Check if proposal passed (simple majority)
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        require(totalVotes > 0, "No votes cast");
        
        if (proposal.forVotes > proposal.againstVotes) {
            proposal.passed = true;
            
            // Execute the proposal if it has a target contract and call data
            if (proposal.targetContract != address(0) && proposal.callData.length > 0) {
                (bool success,) = proposal.targetContract.call(proposal.callData);
                emit ProposalExecuted(_proposalId, success);
            } else {
                emit ProposalExecuted(_proposalId, true);
            }
        } else {
            emit ProposalExecuted(_proposalId, false);
        }
    }
    
    // View functions
    function getProposal(uint256 _proposalId) external view validProposal(_proposalId) returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool passed
    ) {
        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.passed
        );
    }
    
    function getVotingPower(address _voter) external view returns (uint256) {
        return balances[_voter];
    }
    
    function isVotingActive(uint256 _proposalId) external view validProposal(_proposalId) returns (bool) {
        Proposal memory proposal = proposals[_proposalId];
        return (block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime);
    }
}

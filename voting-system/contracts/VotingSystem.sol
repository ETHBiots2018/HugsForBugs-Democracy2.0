pragma solidity ^0.4.18;

import "./TokenERC20.sol";

contract VotingSystem {
    
    // templates
    struct Voting {
        string title;
        string description;
        bool complete;
        uint approvalCount;
        uint rejectionCount;
        TokenERC20 token;
        mapping(address => bool) voters;
    }
    
    struct Proposal {
        string title;
        string description;
        address manager;
        uint needApprovals;
        bool complete;
        uint numberOfApprovals;
        mapping(address => bool) alreadyJoined;
    } 
    
    // system storage
    Voting[] public votings;
    Proposal[] public proposals;
    address public manager;
    uint public votersCount;
    mapping(address => bool) public voters;
    
    modifier restricted() {
        require(msg.sender == manager);
        _;
    }
    
    // =====================================
    // Constructor
    // =====================================
    
    /**
     * Constructor creates voting system with manager initialization
     */
    
    function VotingSystem() public {
        manager = msg.sender;
    }
    
    // =====================================
    // Voting Functions
    // =====================================
    
    function getVotingsCount() public view returns (uint) {
        return votings.length;
    }
    
    function createVoting(string title, string description) public restricted {
      
        TokenERC20 newToken = new TokenERC20(votersCount, "VoteCoin", "VTC");
        Voting memory newVoting = Voting({
            title: title, 
            description: description,
            complete: false,
            approvalCount: 0, 
            rejectionCount: 0, 
            token: newToken
        });
        
        votings.push(newVoting);
    }
    
    function enableVoting(address voter) public restricted {
        require(!voters[voter]);
        votersCount++;
        voters[voter] = true;
    }
    
    function enterVoting(uint index) public payable {
        require(voters[msg.sender]);
        Voting storage voting = votings[index];
        require(!voting.voters[msg.sender]);
        voting.token.transfer(msg.sender, 1);
        voting.voters[msg.sender] = true;
    }
    
    function vote(uint index, bool value) public {
        Voting storage voting = votings[index];
        
        // right and balance requirements
        uint256 currentBalance = voting.token.getBalance(msg.sender);
        require(voting.voters[msg.sender]);
        require(currentBalance >= 1);
        
        // update token
        bool success = voting.token.burnWtihSender(msg.sender, 1);
        require(success);

        // update voting counter
        if (value) {
            voting.approvalCount++;
        } else {
            voting.rejectionCount++;
        }
    }
    
    function voteFor(uint _index, address _for, bool _value) public {
        Voting storage voting = votings[_index];
        
        // check rights and balance
        uint256 currentBalance = voting.token.getBalance(_for);
        require(voting.voters[_for]);
        require(voting.voters[msg.sender]);
        require(currentBalance >= 1);
        
        // update token
        bool success = voting.token.burnFromWithSender(msg.sender, _for, 1);
        require(success);

        // update voting counter
        if (_value) {
            voting.approvalCount++;
        } else {
            voting.rejectionCount++;
        }
    }   

    /**
     * Allows `_to` to spend a vote token on your behalf
     *
     * @param _index voting index for vote transfer
     * @param _to address authorized to spend vote
     */
     
    function transferVote(uint _index, address _to) public {
        Voting storage voting = votings[_index];
        
        // check rights and balance
        uint256 currentBalance = voting.token.getBalance(msg.sender);
        require(voting.voters[_to]);
        require(voting.voters[msg.sender]);
        require(currentBalance >= 1);
        
        // set transfer/allowance
        voting.token.approveWithSender(msg.sender, _to, 1);
    } 
    
    // =====================================
    // Proposal functions
    // =====================================
    
    function createProposal(string title, string description, uint minimum) public {
        Proposal memory newProposal = Proposal({
            title: title, 
            description: description,
            manager: msg.sender,
            complete: false,
            needApprovals: minimum, 
            numberOfApprovals: 0
        });
        
        proposals.push(newProposal);
    }
    
    function createVotingForProposal(uint _index) public {
        Proposal storage proposal = proposals[_index];
        
        require(proposal.manager == msg.sender);
        require(proposal.numberOfApprovals >= proposal.needApprovals);
        
        TokenERC20 newToken = new TokenERC20(votersCount, "VoteCoin", "VTC");
        Voting memory newVoting = Voting({
            title: proposal.title, 
            description: proposal.description,
            complete: false,
            approvalCount: 0, 
            rejectionCount: 0, 
            token: newToken
        });
        
        votings.push(newVoting);
    }

    function getProposalCount() public view returns (uint) {
        return proposals.length;
    }

    function supportProposal(uint index) public {
        Proposal storage proposal = proposals[index];
        
        require(!proposal.alreadyJoined[msg.sender]);
        
        proposal.alreadyJoined[msg.sender] = true;
        proposal.numberOfApprovals++;
    }
    
    function checkProposalStatus (uint index) public view returns (bool) {
        Proposal storage proposal = proposals[index];
        bool result = proposal.numberOfApprovals > proposal.needApprovals;
        return result;
    }
}
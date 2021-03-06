pragma solidity ^0.4.18;

import "./TokenERC20.sol";

contract VotingSystem {
    
    // templates
    struct Voting {
        string title;
        string description;
        uint approvalCount;
        uint rejectionCount;
        uint maxVoterCount;
        uint balance;
        uint payment;
        TokenERC20 token;
        uint endTime;
        bool complete;
        bool transferVoteAllowed;
        mapping(address => bool) voters;
        mapping(address => VoteCounter) votes;
    }

    struct VoteCounter {
        uint yesVotes;
        uint noVotes;
    }
    
    // system storage
    // note: for debugging/testing purposes these were set to public, 
    // but for a productive implementation these should be set to private
    // left here public, because testing was done with them on public.
    Voting[] public votings;
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

    function finalizeVoting(uint index) public restricted returns (uint, uint, uint) {
        Voting storage voting = votings[index];
        require(now > voting.endTime);
        voting.complete = true;
        clearBalance(index);
        return(voting.maxVoterCount, voting.approvalCount, voting.rejectionCount);
    }

    function clearBalance(uint _index) public restricted {
        Voting storage voting = votings[_index];
        require(voting.complete);        
        manager.transfer(voting.balance);
    }
    
    // =====================================
    // Voting Functions
    // =====================================
    
    function getVotingsCount() public view restricted returns (uint) {
        return votings.length;
    }
    
    // duration is time in seconds for which voting is open
    // transferVoteAllowed specifies if votes can be transfered to another person
    function createVoting(string title, string description, uint duration, bool _transferVoteAllowed) public restricted payable {
      
        //overflow check
        require(now <= now + duration);
        require(votersCount > 0);

        TokenERC20 newToken = new TokenERC20(votersCount, "VoteCoin", "VTC");
        uint p = msg.value / votersCount;
        Voting memory newVoting = Voting({
            title: title,
            description: description,
            approvalCount: 0,
            rejectionCount: 0,
            maxVoterCount: votersCount,
            balance: msg.value,
            payment: p,
            token: newToken,
            endTime: now + duration,
            complete: false,
            transferVoteAllowed: _transferVoteAllowed
        });
        
        votings.push(newVoting);
    }
    
    function enableVoting(address voter) public restricted {
        require(!voters[voter]);
        votersCount++;
        voters[voter] = true;
    }

    // we chose not to include this as it would give the owner power to manipulate
    // a vote
    /*function disableVoter(address voter, uint index) {
         require(voters[voter]);
         votersCount--;
         voters[voter] = false;
 
         Voting storage voting = votings[index];
         require(now <= voting.endTime);
         uint yesCount = voting.votes[voter].yesVotes;
         uint noCount = voting.votes[voter].noVotes;
 
         // reset voters vote counts
         voting.votes[voter].yesVotes = 0;
         voting.votes[voter].noVotes = 0;
 
         // revert a voters votes
         voting.approvalCount -= yesCount;
         voting.rejectionCount -= noCount;
    }*/
   
    function enterVoting(uint index) public payable {
        require(voters[msg.sender]);
        Voting storage voting = votings[index];
        require(now <= voting.endTime);
        require(!voting.voters[msg.sender]);
        voting.token.transfer(msg.sender, 1);
        voting.voters[msg.sender] = true;
    }
    
    function vote(uint index, bool value) public {
        Voting storage voting = votings[index];
        require(now <= voting.endTime);
        
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
            voting.votes[msg.sender].yesVotes++;
        } else {
            voting.rejectionCount++;
            voting.votes[msg.sender].noVotes++;
        }
        
        // payment if any balance
        msg.sender.transfer(voting.payment);
        voting.balance -= voting.payment;
    }
    
    function voteFor(uint _index, address _for, bool _value) public {
        Voting storage voting = votings[_index];
        require(now <= voting.endTime);
        require(voting.transferVoteAllowed);
        
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
            voting.votes[_for].yesVotes++;
        } else {
            voting.rejectionCount++;
            voting.votes[_for].noVotes++;
        }
        
        // payment if any balance
        msg.sender.transfer(voting.payment);
        voting.balance -= voting.payment;
    }  

    function changeVote (uint index, bool fromValue, bool toValue) public {
         // if you change vote to the same, nothing happens
         require(fromValue != toValue);
 
         Voting storage voting = votings[index];
         require(voting.voters[msg.sender]);
         
         if (fromValue == true) {
             // toValue has to be false at this point
             // person has to have a yes vote to revert
             require(voting.votes[msg.sender].yesVotes >= 1);
             voting.votes[msg.sender].yesVotes--;
             voting.votes[msg.sender].noVotes++;
            voting.approvalCount--;
             voting.rejectionCount++;
         } else {
             // same as above but vice versa
             require(voting.votes[msg.sender].noVotes >= 1);
             voting.votes[msg.sender].noVotes--;
             voting.votes[msg.sender].yesVotes++;
             voting.rejectionCount--;
             voting.approvalCount++;
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
        require(now <= voting.endTime);
        require(voting.transferVoteAllowed);
        
        // check rights and balance
        uint256 currentBalance = voting.token.getBalance(msg.sender);
        require(voting.voters[_to]);
        require(voting.voters[msg.sender]);
        require(currentBalance >= 1);
        
        // set transfer/allowance
        voting.token.approveWithSender(msg.sender, _to, 1);
    } 
    
}
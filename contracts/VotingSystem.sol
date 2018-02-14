pragma solidity ^0.4.18;

contract VotingSystem {
    struct Voting {
        string title;
        string description;
        bool complete;
        uint approvalCount;
        uint rejectionCount;
        mapping(address => bool) approvals;
        mapping(address => bool) rejections;
    }
    
    Voting[] public votings;
    address manager;
    mapping(address => bool) voters;
    
    modifier restricted() {
        require(msg.sender == manager);
        _;
    }
    
    function VotingSystem() public {
        manager = msg.sender;
    }
    
    function createVoting() public {
        
    }
    
}
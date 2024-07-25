// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyWallet { 
     string  public name;
     mapping (address => bool) private approved;
     address public owner;

    modifier auth {
        require (msg.sender == owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    } 

    function transferOwernship(address _addr) public  auth {
        require(_addr!=address(0), "New owner is the zero address");
        require(owner != _addr, "New owner is the same as the old owner");
        owner = _addr;
    }

    function setOwnerUsingAssembly(address newOwner) public auth {
        require(newOwner != address(0), "New owner is the zero address");
        require(newOwner != owner, "New owner is the same as the old owner");
        assembly {
            sstore(2, newOwner)
        }
    }


    function getOwnerUsingAssembly() public view returns (address) {
        address currentOwner;
        assembly {
            // Load the value at slot 2 into the currentOwner variable
            currentOwner := sload(2)
        }
        return currentOwner;
    }

}
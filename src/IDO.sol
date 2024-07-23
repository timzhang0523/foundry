// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TZToken is ERC20 {
    constructor() ERC20("TESTZ", "TZ") {
        _mint(msg.sender, 2e9 ether);
    }
}

contract IDO {
    uint256 public constant MIN_PAY = 0.0001 ether;
    uint256 public constant Max_Limit = 200 ether;
    uint256 public constant Target = 100 ether;
    uint256 public constant ERC20_Amount = 1000000 ether;
    uint256 public EventEndTime ;
    uint256 public poolEthAmount ;
    IERC20  public token;
    uint256 private _amount;
    mapping(address => uint256) public balances;
    address owner;
    event Presale(address user,uint256 amount);
    event Claim(address user,uint256 amount);
    event Withdraw(address user,uint256 amount);
    event Refund(address user,uint256 amount);

    constructor (address _erc20){
        owner = msg.sender;
        token = IERC20(_erc20);
        EventEndTime = block.timestamp + 30 days;
    }

    function setIDOToken(address _erc20) external{
        require(msg.sender == owner,"invalid owner!");
        token = IERC20(_erc20);
    }
    function presale() public payable onlyActive {
        require(token.balanceOf(address(this)) == ERC20_Amount,"No ERC20 token in pool");
        // _update();
        poolEthAmount += msg.value;
        balances[msg.sender] += msg.value;
        emit Presale(msg.sender, msg.value);
    }


    function claim() external onlySuccess {
        balances[msg.sender] = 0;
        uint256 getTokenAmount = balances[msg.sender] * ERC20_Amount / poolEthAmount;
        token.transfer(msg.sender,getTokenAmount);
        emit Claim(msg.sender,getTokenAmount);
    }

    function withdraw() external onlySuccess{
        require(msg.sender == owner,"invalid owner!");
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "IDO: transfer failed");
        emit Withdraw(msg.sender, address(this).balance);
    }

    function refund() external onlyFailed {
        require(balances[msg.sender] >= 0,"Insufficient balance~");
        (bool success,) = msg.sender.call{value: balances[msg.sender]}("");
        require(success, "IDO: transfer failed");
        balances[msg.sender] = 0;
        emit Refund(msg.sender, balances[msg.sender]);
    }
    modifier onlySuccess() {
        require(block.timestamp >= EventEndTime,"claim time not start~");
        require(poolEthAmount >= Target,"Target not success~");
        _;
    }

    modifier onlyFailed() {
        require(block.timestamp >= EventEndTime,"claim time not start~");
        require(poolEthAmount < Target,"Target not success~");
        _;
    }

    modifier onlyActive() {
        require(block.timestamp < EventEndTime && msg.value + poolEthAmount < Max_Limit,"not active~");
        require(msg.value >= MIN_PAY,"Insufficient balance~");
        _;
    }

}

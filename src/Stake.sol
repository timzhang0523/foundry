// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";


contract esRNTToken is ERC20 {
    using SafeERC20 for IERC20;
    address owner;
    address public stake;
    struct LockInfo {
        address user;
        uint256 amount;
        uint256 lockTime;
    }
    
    IERC20 public RNT;
    LockInfo[] public userLocks; 
    event SwapRNT(address indexed user, uint256 amount);

    constructor(address _RNT) ERC20("Locked Reward Network Token", "esRNT") {
        owner = msg.sender;
        RNT = IERC20(_RNT);
        // stake = _stake;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner);
        _mint(to, amount);
    }
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function stakeMint(address to, uint256 amount) external {
        require(msg.sender == stake,"invalid address");
        _mint(to, amount);
        IERC20(RNT).transferFrom(msg.sender, address(this), amount);
        LockInfo memory newLock = LockInfo({
            user: to,
            amount: amount,
            lockTime: block.timestamp
        });
        userLocks.push(newLock);
    }

    function setStake(address _stake) public {
        require(msg.sender == owner,"not owner address");
        stake = _stake;
    }


    function getLocksByUser(address user) public  view returns (uint256 lockAmount,uint256 lockTime) {
        for (uint256 i = 0; i < userLocks.length; i++) {
            if (userLocks[i].user == user) {
                lockAmount = userLocks[i].amount;
                lockTime = userLocks[i].lockTime;
            }
        }
    }

    function swapRNT(address user,uint256 amount) external {
        require(msg.sender == stake,"invalid address");
        (uint256 lockAmount,uint256 lockTime) = getLocksByUser(user);
        require(lockAmount >= amount,"Insufficient locked amount");
        uint256 timeStaked = block.timestamp - lockTime;

        uint256 unlockedAmount = (timeStaked >= 30 days) ? amount : (amount * timeStaked) / 30 days;
        if (unlockedAmount > 0) {
            IERC20(RNT).safeTransfer(user, unlockedAmount);
            IERC20(RNT).safeTransfer(address(0x1), amount - unlockedAmount);
        }
        emit SwapRNT(user, unlockedAmount);
    }

    function addLock(address user, uint256 amount) external {
        require(msg.sender == owner, "Only the stake contract can call this function");
        LockInfo memory newLock = LockInfo({
            user: user,
            amount: amount,
            lockTime: block.timestamp
        });
        userLocks.push(newLock);
    }
    

}

interface IesRNT {
    function stakeMint(address to,uint256 amount) external ;
    function swapRNT(address user,uint256 amount) external ;
}

contract StakePool {
    using SafeERC20 for IERC20;
    IERC20 public RNT;
    IERC20 public esRNT;

    struct StakerInfo {
        uint256 amount; 
        uint256 unclaimed; 
        uint256 lastStakeTime;
    }
    uint256 public accRewardPerShare;
    uint256 public totalStaked;
    uint256 public rewardRNT = 1 ether; // 1 esRNT per RNT per day
    mapping(address => StakerInfo) public stakers;

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 reward);

    constructor(IERC20 _RNT, IERC20 _esRNT) {
        RNT = _RNT;
        esRNT = _esRNT;
    }

    function stake(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
        ) external {
        updatePool();
        StakerInfo storage user = stakers[msg.sender];
        IERC20Permit(address(RNT)).permit(msg.sender, address(this), amount, deadline, v, r, s);
        RNT.safeTransferFrom(msg.sender, address(this), amount);
        user.unclaimed = user.amount * accRewardPerShare / 1e18;
        user.amount += amount;
        user.lastStakeTime = block.timestamp;
        totalStaked += amount;
        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        StakerInfo storage user = stakers[msg.sender];
        require(user.amount >= amount, "Insufficient staked amount");
        updatePool();
        user.unclaimed = user.amount * accRewardPerShare / 1e18;
        user.amount -= amount;
        user.lastStakeTime = block.timestamp;
        RNT.safeTransfer(msg.sender, amount);
        totalStaked -= amount;
        emit Unstake(msg.sender, amount);
    }

    function getUserStakeInfo(address _user) public view returns (uint256 amount,uint256 unclaimed,uint256 time) {
        StakerInfo memory user = stakers[_user];
        unclaimed = user.unclaimed ;
        amount = user.amount;
        time = user.lastStakeTime;
    }


    function claim() external {
        updatePool();
        StakerInfo storage user = stakers[msg.sender];
        uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.unclaimed;
        require(pending > 0, "No rewards to claim");
        
        RNT.approve(address(esRNT),2**256 - 1);
        IesRNT(address(esRNT)).stakeMint(msg.sender, pending);
        
        user.unclaimed = 0;
        user.lastStakeTime = block.timestamp;
        emit ClaimReward(msg.sender, pending);
    }

    function swapRNT(uint256 amount) external {
        IesRNT(address(esRNT)).swapRNT(msg.sender,amount);
    }

    function updatePool() internal {
        if (totalStaked > 0) {
            uint256 multiplier = block.timestamp - stakers[msg.sender].lastStakeTime;
            uint256 reward = multiplier * rewardRNT * 1e18 / 1 days;
            accRewardPerShare += reward / totalStaked;
        }
    }

}

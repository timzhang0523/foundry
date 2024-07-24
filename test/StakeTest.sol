// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,Vm,console} from "forge-std/Test.sol";

import {ZLERC20Permit} from  "../src/ZLERC20Permit.sol";
import {StakePool,esRNTToken} from "../src/Stake.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface StakeEvent{
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 reward);
    event SwapRNT(address user, uint256 reward);
}

contract StakeTest is Test,StakeEvent {
    using ECDSA for bytes32;
    address public randomUser;
    uint256 public privatePK;
    address public admin;
    StakePool public stake;
    ZLERC20Permit public RNTToken ;
    esRNTToken public esRNT;
    uint256 public amount = 10000 ether;
    // uint256 public _amount = 10 ether;
    uint256 public nonce;
    uint256 public deadline = block.timestamp + 1 hours;
    struct LockInfo {
        address user;
        uint256 amount;
        uint256 lockTime;
    }
    function setUp() public {
        // user = makeAddr("user");
        admin = makeAddr("admin");
        // startPrank("admin");
        RNTToken = new ZLERC20Permit();
        admin = makeAddr("admin");
        vm.prank(admin);
        esRNT = new esRNTToken(address(RNTToken));
        vm.prank(admin);
        stake = new StakePool(RNTToken,esRNT);
        vm.prank(admin);
        esRNT.setStake(address(stake));
        (randomUser,privatePK) = makeAddrAndKey("randomUser");
        nonce = RNTToken.nonces(randomUser);

        // uint256 _amount = 10 ether;
        // vm.deal(address(RNTToken),address(esRNT),_amount);

    }

    function testStake() public {
        // uint256 amount = 10000 ether;
        deal(address(RNTToken),randomUser, amount);
        (uint8 v, bytes32 r, bytes32 s) =_getERC20Signature();
        vm.startPrank(randomUser);
        vm.expectEmit(true, true, false, false);
        emit Stake(randomUser, amount);
        stake.stake(amount, deadline, v, r, s);
        (uint256 balance,,)=stake.getUserStakeInfo(randomUser);

        assertEq(RNTToken.balanceOf(address(stake)),amount,"STAKE: token is not ready~");

        assertEq(stake.totalStaked(),amount,"STAKE: stake token failed~");
        assertEq(amount,balance,"STAKE: token mismatch~");

    }
    // ClaimReward(user, reward);
    function testClaim() public {
        deal(address(RNTToken),randomUser, amount);
        // vm.assume(_amount >0 && _amount <= amount);
        (uint8 v, bytes32 r, bytes32 s) =_getERC20Signature();
        vm.prank(randomUser);
        stake.stake(amount, deadline, v, r, s);


        assertEq(esRNT.stake(),address(stake),"esRNT: error stake address~");

        uint256 unstakeTime = block.timestamp + 3 days;
        vm.warp(unstakeTime); 
        (uint256 curAmount,,uint256 lastStakeTime) = stake.getUserStakeInfo(randomUser);

        // 计算收益
        // 用户质押数量 * RNT每天奖励数量 * （now - laststaketime）* 1e12 / 1 days / 用户总质押量
        uint256 accRewardPerShare = stake.rewardRNT() * (unstakeTime - lastStakeTime) * 1e18 / 1 days / stake.totalStaked();
        uint256 unclaimedReward = curAmount * accRewardPerShare / 1e18;
        vm.prank(address(stake));
        RNTToken.approve(address(esRNT), 2**256-1);
        assertGt(RNTToken.allowance(address(stake), address(esRNT)),0,"esRNT: error approve~");

        vm.expectEmit(true, true, false, false);
        emit ClaimReward(randomUser, unclaimedReward);
        vm.prank(randomUser);
        stake.claim();
        vm.prank(address(stake));
        // RNTToken.approve(address(esRNT), 2**256-1);

        assertEq(RNTToken.balanceOf(address(esRNT)),unclaimedReward,"esRNT: reward mismatch~");

        // assertEq(stake.stakers[randomUser].unclaimed,0,"esRNT: error info~");

    }

    function testUnstake(uint256 _amount) public {
        deal(address(RNTToken),randomUser, amount);
        vm.assume(_amount >0 && _amount <= amount);
        (uint8 v, bytes32 r, bytes32 s) =_getERC20Signature();
        vm.prank(randomUser);
        stake.stake(amount, deadline, v, r, s);

        (uint256 preAmount,,uint256 lastStakeTime) = stake.getUserStakeInfo(randomUser);
        assertEq(preAmount, amount);
        vm.expectEmit(true, true, false, false);
        emit Unstake(randomUser, _amount);
        // vm.prank(randomUser);
        uint256 unstakeTime = 1721992131;//
        vm.warp(unstakeTime); 
        // 计算收益
        // 用户质押数量 * RNT每天奖励数量 * （now - laststaketime）* 1e12 / 1 days / 用户总质押量
        uint256 accRewardPerShare = stake.rewardRNT() * (unstakeTime - lastStakeTime) * 1e18 / 1 days / stake.totalStaked();
        uint256 unclaimedReward = preAmount * accRewardPerShare / 1e18;
        vm.prank(randomUser);
        stake.unstake(_amount);
        (uint256 balance,uint256 reward,uint256 stakeTime) = stake.getUserStakeInfo(randomUser);

        assertEq(stakeTime, unstakeTime,"STAKE: error time!");
        assertEq(RNTToken.balanceOf(address(stake)),amount - _amount,"STAKE: token is not ready~");
        assertEq(stake.totalStaked(),amount - _amount,"STAKE: stake token failed~");
        assertEq(RNTToken.balanceOf(randomUser),_amount,"STAKE: token is not ready~");
        assertEq(balance, amount - _amount,"STAKE: ERROR balance!");
        assertEq(reward, unclaimedReward,"STAKE: reward mismatch!");
    }

    function testSwapRNT() public {
        uint256 _amount = 10 ether;
        // deal(address(RNTToken),randomUser, amount);
        deal(address(RNTToken),address(esRNT),_amount );
        assertEq(RNTToken.balanceOf(address(esRNT)), _amount,"STAKE: lockAmount mismatch!");
        vm.prank(admin);

        esRNT.addLock(randomUser, _amount);
        (uint256 lockAmount,) = esRNT.getLocksByUser(randomUser);
        assertEq(lockAmount, _amount,"STAKE: lockAmount mismatch!");
        uint256 esBalance = RNTToken.balanceOf(address(esRNT));
        assertEq(_amount, esBalance,"STAKE: RNT balance mismatch!");
        vm.warp(block.timestamp + 20 days); // 设置超过31 天的时间戳
        vm.expectEmit(true, true, false, false);
        emit SwapRNT(randomUser, esBalance);
        vm.prank(randomUser);
        stake.swapRNT(_amount);

        assertEq(RNTToken.balanceOf(address(randomUser)),esBalance ,"STAKE's balance mismatch!");
        assertEq(RNTToken.balanceOf(address(esRNT)),esBalance - _amount ,"STAKE's balance mismatch!");
    }

    function _getERC20Signature() private view returns (uint8 v, bytes32 r, bytes32 s){
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                randomUser,
                address(stake),
                amount,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                RNTToken.DOMAIN_SEPARATOR(),
                structHash
            )
        );
        (v, r, s) = vm.sign(privatePK, digest);
        return (v,r,s);
    }


}

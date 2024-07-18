// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,Vm,console} from "forge-std/Test.sol";

// import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC721Mock} from "../src/MockERC721.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {NFTMarket} from "../src/nftMarket.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract NFTMarketTest is Test {
    NFTMarket public nftMarket;
    MockERC20 public erc20;
    ERC721Mock public erc721;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public otherBuyer = address(0x1234);
    error ERC721InvalidOperator(address to );
    error ERC721InsufficientApproval(address to,uint);
    error ERC20InsufficientBalance(address spender, uint currentAllowance, uint value);

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Purchased(uint256 indexed tokenId, address indexed buyer, uint256 price);

    function setUp() public {
        
        erc20 = new MockERC20("CCR","CC");
        erc721 = new ERC721Mock("zhanglu","zl");
        nftMarket = new NFTMarket(address(erc20),address(erc721)); 
        deal(address(erc20),alice, 1e9 ether);
        deal(address(erc20),bob, 1e9 ether);
        deal(address(erc20),otherBuyer, 1e9 ether);
    }
    /**
        测试nFT上架
     */
    function testList(uint price) public {
        // 先铸造nft
        uint256 tokenId = erc721.mint(alice);
        assertEq(erc721.ownerOf(tokenId), alice);
        // deal(address(erc20),alice, 1e9 ether);
        vm.startPrank(alice); 
        vm.assume(price > 0 && price < 1e9 ether);
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.isApprovedForAll(alice,address(nftMarket)), true,"emitted approved all  mismatch");
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        vm.expectEmit(true, true, false, true);
        emit Listed(tokenId,alice,price);
        nftMarket.list(tokenId, price);
        vm.stopPrank();
        assertEq(erc721.balanceOf(address(nftMarket)), 1);
        assertEq(erc721.ownerOf(tokenId), address(nftMarket));
    }
    /// 测试NFT 未授权给交易市场 报revert error
    function testNoApprovedList(uint256 price) public {
        vm.assume(price > 0 && price < 1e9 );
        uint256 tokenId = erc721.mint(alice);
        assertEq(erc721.ownerOf(tokenId), alice);

        vm.startPrank(alice); 
        vm.assume(price > 0 && price < 1e9 );
        // 测试是否授权
        vm.expectRevert(abi.encodeWithSignature("ERC721InsufficientApproval(address,uint256)",address(nftMarket),tokenId));
        nftMarket.list(tokenId, price);
        // assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        vm.stopPrank();

    }
    // 购买NFT成功
    function testBuyNFT() public {
        uint256 tokenId = erc721.mint(alice);
        assertEq(erc721.ownerOf(tokenId), alice);
        // deal(address(erc20),alice, 1e9 ether);
        vm.startPrank(alice); 
        uint price = 10 ether;
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.isApprovedForAll(alice,address(nftMarket)), true,"emitted approved all  mismatch");
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        vm.expectEmit(true, true, false, true);
        emit Listed(tokenId,alice,price);
        nftMarket.list(tokenId, price);
        vm.stopPrank();
        
        vm.startPrank(bob); 
        (,uint _price) = nftMarket.getListing(tokenId);
        vm.assume(_price > 0);

        erc20.approve(address(nftMarket), _price);
        assertEq(erc20.allowance(bob, address(nftMarket)),_price,"emitted approved for market mismatch");
        vm.expectEmit(true, true, false, true);
        emit Purchased(tokenId,bob,_price);
        nftMarket.buyNFT(tokenId,_price);
        vm.stopPrank();

        assertEq(erc721.ownerOf(tokenId), bob);
        // 检查上架的商品是否清空
        (address _seller,uint _price1) = nftMarket.getListing(tokenId);
        assertEq(_seller, address(0));
        assertEq(_price1, 0);

    }
    // 自己购买自己 && 别人也参与购买
    function testBuyNFTMultiReason() public {
        uint256 tokenId = erc721.mint(alice);
        assertEq(erc721.ownerOf(tokenId), alice);
        // deal(address(erc20),alice, 1e9 ether);
        vm.startPrank(alice); 
        uint256 price = 10 ether;
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.isApprovedForAll(alice,address(nftMarket)), true,"emitted approved all  mismatch");
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        vm.expectEmit(true, true, false, true);
        emit Listed(tokenId,alice,price);
        nftMarket.list(tokenId, price);
        vm.stopPrank();
        
        vm.startPrank(alice); 
        (,uint _price) = nftMarket.getListing(tokenId);
        vm.assume(_price > 0);

        erc20.approve(address(nftMarket), _price);
        assertEq(erc20.allowance(alice, address(nftMarket)),_price,"emitted approved for market mismatch");

        vm.expectEmit(true, true, false, true);
        emit Purchased(tokenId,alice,_price);
        nftMarket.buyNFT(tokenId,_price);
        vm.stopPrank();

        assertEq(erc721.ownerOf(tokenId), alice,"mismatch~");
        // 检查上架的商品是否清空
        (address _seller,uint _price1) = nftMarket.getListing(tokenId);
        assertEq(_seller, address(0));
        assertEq(_price1, 0);
        // 检查是否可以重复购买
        vm.startPrank(otherBuyer);
        vm.expectRevert("This NFT is not for sale");
        nftMarket.buyNFT(tokenId,_price);
        vm.stopPrank();

    }
    //  支付金额不足
    function testBuyNftInsufficientAllowance() public {
        uint256 tokenId = erc721.mint(alice);
        vm.startPrank(alice); 
        uint256 price = 10 ether;
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        nftMarket.list(tokenId, price);
        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = nftMarket.getListing(tokenId);
        assertEq(listedSeller, alice);
        assertEq(listedPrice, price);

        vm.startPrank(bob);
        erc20.approve(address(nftMarket), price - 1 ether);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientAllowance(address,uint256,uint256)",address(nftMarket),price - 1 ether,price));
        nftMarket.buyNFT(tokenId,price);
        vm.stopPrank();

        vm.startPrank(otherBuyer);
        erc20.approve(address(nftMarket), price - 1 ether);
        vm.expectRevert("Insufficient amount");
        nftMarket.buyNFT(tokenId,price -1 ether);
        vm.stopPrank();
    }

    // 支付金额过多
    function testBuyNftAddAllowance() public {
        uint256 tokenId = erc721.mint(alice);
        vm.startPrank(alice); 
        uint256 price = 10 ether;
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        nftMarket.list(tokenId, price);
        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = nftMarket.getListing(tokenId);
        assertEq(listedSeller, alice);
        assertEq(listedPrice, price);

        vm.startPrank(bob);
        erc20.approve(address(nftMarket), price + 1 ether);
        vm.expectEmit(true, true, false, true);
        emit Purchased(tokenId,bob,price);
        nftMarket.buyNFT(tokenId,price + 1 ether);
        vm.stopPrank();
    }
    // 购买者金额不足
    function testBuyNftInsufficientAmount() public {
        uint256 price = 10 ether;
        uint256 tokenId = erc721.mint(alice);
        vm.startPrank(alice); 
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        nftMarket.list(tokenId, price);
        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = nftMarket.getListing(tokenId);
        assertEq(listedSeller, alice);
        assertEq(listedPrice, price);
        address randomUser = vm.addr(
            uint256(keccak256(abi.encodePacked("randomUser", block.timestamp)))
        );
        vm.startPrank(randomUser);
        erc20.approve(address(nftMarket), price);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)",randomUser,erc20.balanceOf(randomUser),price));
        nftMarket.buyNFT(tokenId,price );
        vm.stopPrank();
    }

    function testFuzzBuyNft(uint price) public {
        vm.assume(price > 0.01 ether && price < 10000 ether );

        uint256 tokenId = erc721.mint(alice);
        vm.startPrank(alice); 
        // 测试是否授权
        erc721.setApprovalForAll(address(nftMarket), true);
        assertEq(erc721.ownerOf(tokenId),alice,"emitted owner  mismatch");
        nftMarket.list(tokenId, price);
        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = nftMarket.getListing(tokenId);
        assertEq(listedSeller, alice);
        assertEq(listedPrice, price);
        address randomUser = vm.addr(
            uint256(keccak256(abi.encodePacked("randomUser", block.timestamp)))
        );
        vm.startPrank(randomUser);
        erc20.approve(address(nftMarket), price);
        deal(address(erc20),randomUser, 1e9 ether);
        vm.expectEmit(true, true, false, true);
        emit Purchased(tokenId,randomUser,price);
        nftMarket.buyNFT(tokenId,price );
        vm.stopPrank();
    }

    // function invariantNoTokenBalanceNftMarket() public {
    //     uint256 marketplaceBalance = erc20.balanceOf(address(nftMarket));
    //     assertEq(marketplaceBalance, 0, "Marketplace contract has token balance");
    // }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,Vm,console} from "forge-std/Test.sol";
import {ERC721Mock} from "../src/MockERC721.sol";
import {ZLERC20Permit} from "../src/ZLERC20Permit.sol";
import {NFTMarketplaceNoList} from "../src/NFTMarketplaceNoList.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract NFTMarketNoListPermitTest is Test {
    NFTMarketplaceNoList public nftMarket;
    ZLERC20Permit public erc20;
    ERC721Mock public erc721;
    uint256 public private_key ;
    address public alice; // as master
    address public seller;
    uint256 public sellerPK;
    uint256 public price = 2 ether;
    uint256 public deadline;
    address public buyer ;
    uint256 tokenId;
    uint256 public buyerPK;
    address public otherBuyer = address(0x1234);
    address public constant ETH_FLAG = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    error ERC721InvalidOperator(address to );
    error ERC721InsufficientApproval(address to,uint);
    error ERC20InsufficientBalance(address spender, uint currentAllowance, uint value);
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    // event Sold(address indexed buyer, uint256 price,
    
    // SellOrder dorder);

    function setUp() public {
        (alice,private_key) = makeAddrAndKey("alice"); // owner
        (buyer,buyerPK) = makeAddrAndKey("buyer"); // buyer 
        (seller,sellerPK) = makeAddrAndKey("seller"); // seller 

        erc20 = new ZLERC20Permit();
        erc721 = new ERC721Mock("zhanglu","zl");
        deadline = block.timestamp + 2 days;
        vm.prank(alice);
        nftMarket = new NFTMarketplaceNoList(); 
        tokenId = erc721.mint(seller);
        deal(buyer, 2 ether);
        vm.prank(seller);
        erc721.setApprovalForAll(address(nftMarket), true);
    }

    // 购买NFT成功
    function testCancel() public {
        vm.startPrank(seller);
        NFTMarketplaceNoList.SellOrder memory sellOrder = NFTMarketplaceNoList.SellOrder({
            seller:seller,
            nft:address(erc721),
            tokenId:tokenId,
            payToken:ETH_FLAG,
            price:price,
            deadline:deadline
        });
        
        nftMarket.cancel(sellOrder);
        vm.stopPrank();

    }

    function testBuyPermitWithNoList() public {
        vm.startPrank(seller); 
        assertEq(erc721.ownerOf(tokenId),seller,"emitted owner  mismatch");
        // 验证是否授权到nftmarket
        assertEq(erc721.isApprovedForAll(seller,address(nftMarket)), true,"emitted approved all  mismatch");

        NFTMarketplaceNoList.SellOrder memory sellOrder = NFTMarketplaceNoList.SellOrder({
            seller:seller,
            nft:address(erc721),
            tokenId:tokenId,
            payToken:ETH_FLAG,
            price:price,
            deadline:deadline
        });
        bytes32 digest = nftMarket.hashBuyWithList(sellOrder); 
        (uint8 v, bytes32 r, bytes32 s) =vm.sign(sellerPK, digest); 
        bytes memory signatureListing = abi.encodePacked(r,s,v);
        assertEq(signatureListing.length,65,"signature listing mismatch");
        vm.stopPrank();

        vm.startPrank(buyer); 
        // vm.expectEmit(true, true, false, true);
        // emit Sold(buyer,tokenId,sellOrder);
        nftMarket.buy{value:buyer.balance}(signatureListing,sellOrder);
        vm.stopPrank();

        assertEq(erc721.ownerOf(tokenId), buyer);
        assertEq(buyer.balance, 0,"balance mismatch!!!");

    }

}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {ClausBuybackVaultV2, PoolKey, Currency, IHooks} from "../flat/ClausBuybackVaultV2.sol";
interface DonationVm {
    function chainId(uint256) external;
    function etch(address,bytes calldata) external;
    function deal(address,uint256) external;
    function prank(address) external;
    function expectRevert() external;
}
contract DonationTokenMock {
    mapping(address=>uint256) public balanceOf;
    uint256 public totalSupply;
    function mint(address to,uint256 amount) external {balanceOf[to]+=amount;totalSupply+=amount;}
    function burn(uint256 amount) external {balanceOf[msg.sender]-=amount;totalSupply-=amount;}
}
contract DonationManagerMock {
    bool public locked;
    function setLocked(bool value) external {locked=value;}
    function exttload(bytes32) external view returns(bytes32){return bytes32(uint256(locked?1:0));}
}
contract DonationHookMock {}
contract DonationBurnTest {
    DonationVm constant vm=DonationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant manager=0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address constant keeper=address(0xBEEF);
    DonationTokenMock token;
    ClausBuybackVaultV2 vault;
    function setUp() public {
        vm.chainId(4663);
        vm.etch(manager,type(DonationManagerMock).runtimeCode);
        token=new DonationTokenMock();
        PoolKey memory key=PoolKey(Currency.wrap(address(0)),Currency.wrap(address(token)),0x800000,60,IHooks(address(new DonationHookMock())));
        vault=new ClausBuybackVaultV2(address(this),key,keeper,0.5 ether);
    }
    function testOwnerBurnsDonationWithoutSpendingEthOrInflatingBuybacks() public {
        token.mint(address(vault),123 ether);vm.deal(address(vault),1 ether);
        vault.configure(keeper,0.5 ether,false);
        require(vault.burnDonatedTokens()==123 ether,"burn amount");
        require(token.balanceOf(address(vault))==0&&token.totalSupply()==0,"token accounting");
        require(address(vault).balance==1 ether,"ETH changed");
        require(vault.totalDonatedTokensBurned()==123 ether,"donation counter");
        require(vault.totalTokensBurned()==0&&vault.totalEthSpent()==0&&vault.lastBuybackBlock()==0,"buyback accounting changed");
    }
    function testKeeperCannotBurnDonations() public {
        token.mint(address(vault),1 ether);
        vm.prank(keeper);vm.expectRevert();vault.burnDonatedTokens();
        require(token.balanceOf(address(vault))==1 ether,"unauthorized burn");
    }
    function testUnlockedManagerBlocksDonationBurn() public {
        token.mint(address(vault),1 ether);DonationManagerMock(manager).setLocked(true);
        vm.expectRevert();vault.burnDonatedTokens();
        require(token.balanceOf(address(vault))==1 ether&&vault.totalDonatedTokensBurned()==0,"reverted burn changed state");
    }
    function testEmptyAndRepeatedBurnAreNoOps() public {
        require(vault.burnDonatedTokens()==0,"empty burn");
        token.mint(address(vault),1 ether);vault.burnDonatedTokens();
        require(vault.burnDonatedTokens()==0&&vault.totalDonatedTokensBurned()==1 ether,"repeat burn");
    }
}

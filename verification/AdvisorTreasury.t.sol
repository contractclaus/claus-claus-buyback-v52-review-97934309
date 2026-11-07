// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {MigrationFeeHookV2,PoolKey,Currency,IHooks,SwapParams,BalanceDelta,IPoolManager} from '../flat/MigrationFeeHookV2.sol';
interface AdvisorVm {function etch(address,bytes calldata) external;function deal(address,uint256) external;function prank(address) external;function expectRevert() external;}
interface AdvisorCallback {function unlockCallback(bytes calldata) external returns(bytes memory);}
contract AdvisorManagerMock {
    mapping(address=>uint256) public credits;bool public busy;
    function exttload(bytes32) external view returns(bytes32){return bytes32(uint256(busy?1:0));}
    function extsload(bytes32) external pure returns(bytes32){return bytes32(uint256(1<<96));}
    function mint(address to,uint256,uint256 amount) external {credits[to]+=amount;}
    function burn(address from,uint256,uint256 amount) external {require(msg.sender==from);credits[from]-=amount;}
    function unlock(bytes calldata data) external returns(bytes memory){require(!busy);busy=true;bytes memory result=AdvisorCallback(msg.sender).unlockCallback(data);busy=false;return result;}
    function take(Currency,address to,uint256 amount) external {(bool ok,)=to.call{value:amount}("");require(ok);}
}
contract AdvisorProxy {
    address immutable implementation;
    constructor(address impl,bytes memory data){implementation=impl;(bool ok,)=impl.delegatecall(data);require(ok);}
    fallback() external payable {address target=implementation;assembly {calldatacopy(0,0,calldatasize())let ok:=delegatecall(gas(),target,0,calldatasize(),0,0)returndatacopy(0,0,returndatasize())switch ok case 0 {revert(0,returndatasize())}default{return(0,returndatasize())}}}
}
contract AdvisorRejectsEth {}
contract AdvisorTreasuryTest {
    AdvisorVm constant vm=AdvisorVm(address(uint160(uint256(keccak256('hevm cheat code')))));
    address constant manager=0x8366a39CC670B4001A1121B8F6A443A643e40951;
    MigrationFeeHookV2 hook;PoolKey key;
    receive() external payable {}
    function setUp() public {
        vm.etch(manager,type(AdvisorManagerMock).runtimeCode);vm.deal(manager,100 ether);
        hook=MigrationFeeHookV2(address(new AdvisorProxy(address(new MigrationFeeHookV2()),abi.encodeCall(MigrationFeeHookV2.initialize,(address(this),address(0x1234),address(this),uint160(1<<96),int24(60))))));
        key=PoolKey(Currency.wrap(address(0)),Currency.wrap(address(0x1234)),0x800000,60,IHooks(address(hook)));
        vm.prank(manager);hook.beforeInitialize(address(this),key,uint160(1<<96));
    }
    function trade(uint256 gross) internal {
        uint256 fee=gross*20000/1000000;
        BalanceDelta delta=BalanceDelta.wrap((-int256(gross-fee)<<128)|int256(1));
        vm.prank(manager);hook.afterSwap(address(this),key,SwapParams(true,-int256(gross),1),delta,"");
    }
    function testPriorTreasuryPreservedAndNewTenPercentPaidSeparately() public {
        trade(1 ether);hook.setAdvisorEnabled(true);trade(1 ether);
        (,,uint256 burn,uint256 owner)=hook.allocation();(bool enabled,address advisor,uint24 share,uint256 owed,)=hook.advisorAllocation();
        require(enabled&&share==100000&&advisor==0x1C31B012a8565567A72F7c661D7f0d9f92182853);
        require(burn==0.02 ether&&owner==0.019 ether&&owed==0.001 ether);
        uint256 beforeOwner=address(this).balance;uint256 beforeAdvisor=advisor.balance;
        hook.claimAdvisorFees();hook.claimTreasuryFees();
        require(address(this).balance-beforeOwner==owner&&advisor.balance-beforeAdvisor==owed);
    }
    function testTinyFeesCarryWithoutLosingAdvisorShare() public {
        hook.setAdvisorEnabled(true);for(uint256 i;i<10;i++)trade(50);
        (,,uint256 burn,uint256 owner)=hook.allocation();(,,,uint256 advisor,uint8 remainder)=hook.advisorAllocation();
        require(burn==0&&owner==9&&advisor==1&&remainder==0);
    }
    function testRejectingAdvisorCannotBlockOwnerPayout() public {
        hook.setAdvisorEnabled(true);trade(1 ether);vm.etch(hook.ADVISOR(),type(AdvisorRejectsEth).runtimeCode);
        vm.expectRevert();hook.claimAdvisorFees();(,,,uint256 owed,)=hook.advisorAllocation();require(owed==0.001 ether);
        uint256 before=address(this).balance;hook.claimTreasuryFees();require(address(this).balance-before==0.009 ether);
    }
    function testOnlyOwnerCanToggleAndDisabledDebtRemainsClaimable() public {
        vm.prank(address(0xBEEF));vm.expectRevert();hook.setAdvisorEnabled(true);
        hook.setAdvisorEnabled(true);trade(1 ether);hook.setAdvisorEnabled(false);trade(1 ether);
        (bool enabled,,,uint256 owed,)=hook.advisorAllocation();require(!enabled&&owed==0.001 ether);hook.claimAdvisorFees();
        (,,,owed,)=hook.advisorAllocation();require(owed==0);
    }
}

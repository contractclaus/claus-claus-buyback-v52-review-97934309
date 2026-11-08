// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {ClausBuybackVaultV2, PoolKey, IPoolManager, StateLibrary, IV4Router, IClausRouter} from "../flat/ClausBuybackVaultV2.sol";

interface IExistingBuyback {
    function key() external view returns(PoolKey memory);
    function owner() external view returns(address);
    function keeper() external view returns(address);
    function maxBatch() external view returns(uint128);
    function enabled() external view returns(bool);
    function configure(address,uint128,bool) external;
    function recoverUnspentFees(address payable,uint256) external;
    function totalEthSpent() external view returns(uint256);
    function totalTokensBurned() external view returns(uint256);
    function buyAndBurn(ClausBuybackVaultV2.Plan calldata) external returns(uint256);
}
interface ITransitionHook {
    function owner() external view returns(address);
    function feePips() external view returns(uint24);
    function allocation() external view returns(uint24,address,uint256,uint256);
    function setLiquidityVault(address) external;
    function initializeBuybackOracle() external;
    function minimumBuybackOutput(uint128) external view returns(uint256);
    function buybackOracleState() external view returns(bool,uint64,uint64,int24,uint16);
    function claimTreasuryFees() external;
    function setAdvisorEnabled(bool) external;
    function advisorAllocation() external view returns(bool,address,uint24,uint256,uint8);
    function claimAdvisorFees() external;
}
interface IAdminCalls {
    struct Call {address target;uint256 value;bytes data;}
    function execute(Call[] calldata) external payable returns(bytes[] memory);
    function setTarget(address,bool) external;
    function setOperator(address) external;
}
interface ISupply {function totalSupply() external view returns(uint256);function balanceOf(address) external view returns(uint256);function transfer(address,uint256) external returns(bool);}


interface LiveVm {
 function envOr(string calldata,uint256) external returns(uint256);
 function createSelectFork(string calldata,uint256) external returns(uint256);
 function createSelectFork(string calldata) external returns(uint256);
 function chainId(uint256) external;
 function mockCall(address,bytes calldata,bytes calldata) external;
 function parseJsonBytes(string calldata,string calldata) external pure returns(bytes memory);
 function readFile(string calldata) external view returns(string memory);
 function load(address,bytes32) external view returns(bytes32);
 function expectRevert() external;
 function prank(address) external;
 function deal(address,uint256) external;
 function warp(uint256) external;
}
contract LiveAssertions {
 LiveVm internal constant vm=LiveVm(address(uint160(uint256(keccak256("hevm cheat code")))));
 function assertTrue(bool v) internal pure {require(v,"assert true");}
 function assertFalse(bool v) internal pure {require(!v,"assert false");}
 function assertEq(uint256 a,uint256 b) internal pure {require(a==b,"uint mismatch");}
 function assertEq(address a,address b) internal pure {require(a==b,"address mismatch");}
 function assertEq(bytes32 a,bytes32 b) internal pure {require(a==b,"bytes mismatch");}
 function assertGt(uint256 a,uint256 b) internal pure {require(a>b,"not greater");}
}

contract LiveUpgradeRehearsalTest is LiveAssertions {
    using StateLibrary for IPoolManager;
    address constant HOOK=0x15BBCDB33E6e77f390292d56DED02249C396BFff;
    address constant HOOK_ADMIN=0xf2EAA097f1092437b6157B53D02b9182147c4ac0;
    address constant OLD_VAULT=0x6Be6888C5F8B4A8315eB379eF96D5eeB8E970dCD;
    address constant OPERATOR=0x8aCA8890D34086D7a30B9c06fAe25E0C3cda4cFa;
    address constant TOKEN=0x163015276f3244bC2CcB78b4D69cc8A4069EfFAC;
    address constant MGR=0x8366a39CC670B4001A1121B8F6A443A643e40951;
    bytes32 constant SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    uint256 private forkBlock;
    receive() external payable {}
    function deployArtifact(string memory path,bytes memory args) internal returns(address deployed){
        bytes memory code=abi.encodePacked(vm.parseJsonBytes(vm.readFile(path),".creationBytecode"),args);
        assembly {deployed:=create(0,add(code,32),mload(code))}
        assertTrue(deployed!=address(0));
    }
    function plan(PoolKey memory k,uint128 minimum) internal view returns(ClausBuybackVaultV2.Plan memory){
        (,int24 tick,,)=IPoolManager(MGR).getSlot0(k.toId());
        return ClausBuybackVaultV2.Plan(0.00025 ether,minimum,tick,100,forkBlock-1,keccak256("clock-only-test-stub"),block.timestamp+60);
    }
    function test_exactBytecodesSwitchBurnReturnAndBurnAgain() public {
        forkBlock=vm.envOr("CLAUS_REHEARSAL_BLOCK",uint256(0));
        if(forkBlock==0){vm.createSelectFork("https://rpc.mainnet.chain.robinhood.com");forkBlock=block.number;}
        else vm.createSelectFork("https://rpc.mainnet.chain.robinhood.com",forkBlock);
        vm.chainId(4663);
        vm.mockCall(address(100),abi.encodeWithSignature("arbBlockNumber()"),abi.encode(forkBlock));
        vm.mockCall(address(100),abi.encodeWithSignature("arbBlockHash(uint256)",forkBlock-1),abi.encode(keccak256("clock-only-test-stub")));
        IExistingBuyback old=IExistingBuyback(OLD_VAULT);ITransitionHook hook=ITransitionHook(HOOK);
        address administrator=old.owner();address keeper=old.keeper();uint128 maxBatch=old.maxBatch();
        PoolKey memory k=old.key();bytes32 oldImplementation=vm.load(HOOK,SLOT);
        (uint24 originalShare,,uint256 originalLiquidityOwed,uint256 originalTreasuryOwed)=hook.allocation();
        uint256 oldSpent=old.totalEthSpent();uint256 oldBurned=old.totalTokensBurned();uint256 supply=ISupply(TOKEN).totalSupply();
        address implementation=deployArtifact("build/hook.artifact.json","");
        assertEq(implementation.codehash,bytes32(0x1af00947e569748721a9b23c4a6cdf442e5a62c998eef54e663611abf6951686));
        ClausBuybackVaultV2 next=ClausBuybackVaultV2(payable(deployArtifact("build/vault.artifact.json",abi.encode(administrator,k,keeper,maxBatch))));
        assertEq(address(next).codehash,bytes32(0x8ff1debab8b927c9b324be6082a12140d09233e8d0420f537b523563a8f3e068));
        assertEq(next.owner(),administrator);
        IAdminCalls.Call[] memory control=new IAdminCalls.Call[](1);
        control[0]=IAdminCalls.Call(address(next),0,abi.encodeCall(next.configure,(keeper,maxBatch,false)));
        vm.expectRevert();vm.prank(OPERATOR);IAdminCalls(administrator).execute(control);
        address founder=0xBb145cA83272c3806D4dDc75cA1D5514789cF1C5;
        vm.prank(founder);IAdminCalls(administrator).setTarget(address(next),true);
        vm.prank(founder);IAdminCalls(administrator).setOperator(address(0));
        vm.expectRevert();vm.prank(OPERATOR);IAdminCalls(administrator).execute(control);
        vm.prank(founder);IAdminCalls(administrator).execute(control);assertFalse(next.enabled());
        control[0]=IAdminCalls.Call(address(next),0,abi.encodeCall(next.configure,(keeper,maxBatch,true)));
        vm.prank(founder);IAdminCalls(administrator).execute(control);assertTrue(next.enabled());
        vm.prank(founder);IAdminCalls(administrator).setOperator(OPERATOR);
        IAdminCalls.Call[] memory calls=new IAdminCalls.Call[](6);
        calls[0]=IAdminCalls.Call(OLD_VAULT,0,abi.encodeCall(old.configure,(keeper,maxBatch,false)));
        calls[1]=IAdminCalls.Call(HOOK_ADMIN,0,abi.encodeWithSignature("upgradeAndCall(address,address,bytes)",HOOK,implementation,bytes("")));
        calls[2]=IAdminCalls.Call(HOOK,0,abi.encodeCall(hook.initializeBuybackOracle,()));
        calls[3]=IAdminCalls.Call(HOOK,0,abi.encodeCall(hook.setAdvisorEnabled,(true)));
        calls[4]=IAdminCalls.Call(HOOK,0,abi.encodeCall(hook.setLiquidityVault,(address(next))));
        calls[5]=IAdminCalls.Call(OLD_VAULT,0,abi.encodeCall(old.recoverUnspentFees,(payable(address(next)),OLD_VAULT.balance)));
        vm.prank(OPERATOR);IAdminCalls(administrator).execute(calls);
        assertFalse(old.enabled());assertEq(hook.feePips(),20000);
        (bool ready,uint64 readyAt,,,uint16 observations)=hook.buybackOracleState();
        assertFalse(ready);assertEq(readyAt,block.timestamp+600);assertEq(observations,1);
        vm.prank(administrator);hook.initializeBuybackOracle(); // every owner reset restarts the warmup
        (,,uint256 liquidityOwed,uint256 treasuryOwed)=hook.allocation();
        assertEq(liquidityOwed,originalLiquidityOwed);assertEq(treasuryOwed,originalTreasuryOwed);
        assertEq(originalShare,500000);
        (uint24 share,address destination,,)=hook.allocation();assertEq(share,500000);assertEq(destination,address(next));
        vm.deal(address(next),0.001 ether);
        ClausBuybackVaultV2.Plan memory p=plan(k,1);
        vm.expectRevert();vm.prank(keeper);next.buyAndBurn(p);
        vm.warp(block.timestamp+600);
        p=plan(k,uint128(hook.minimumBuybackOutput(0.00025 ether)));
        vm.prank(keeper);uint256 newBurn=next.buyAndBurn(p);
        assertGt(newBurn,0);assertEq(next.totalEthSpent(),0.00025 ether);assertEq(next.totalTokensBurned(),newBurn);
        assertEq(supply-ISupply(TOKEN).totalSupply(),newBurn);
        (,,,treasuryOwed)=hook.allocation();assertEq(treasuryOwed,originalTreasuryOwed);
        if(treasuryOwed>0){uint256 treasuryBefore=founder.balance;hook.claimTreasuryFees();assertEq(founder.balance-treasuryBefore,treasuryOwed);}
        // A real user swap on the fork of the existing pool accrues the new
        // split, and separate permissionless claims pay both exact receivers.
        // Exercise the actual deployed router as an ordinary (non-exempt) user.
        vm.deal(address(this),1 ether);
        bytes[] memory userActions=new bytes[](3);
        userActions[0]=abi.encode(IV4Router.ExactInputSingleParams(k,true,uint128(0.01 ether),uint128(0),uint256(0),bytes("")));
        userActions[1]=abi.encode(address(0),uint256(0.01 ether));
        userActions[2]=abi.encode(TOKEN,address(this),uint256(0));
        bytes[] memory userInputs=new bytes[](1);
        userInputs[0]=abi.encode(hex"060c0e",userActions);
        IClausRouter(0x204FAca1764B154221e35c0d20aBb3c525710498).execute{value:0.01 ether}(hex"10",userInputs,block.timestamp+60);
        (,,,treasuryOwed)=hook.allocation();
        (bool advisorEnabled,address advisor,uint24 advisorShare,uint256 advisorOwed,)=hook.advisorAllocation();
        assertTrue(advisorEnabled);assertEq(advisor,0x1C31B012a8565567A72F7c661D7f0d9f92182853);assertEq(advisorShare,100000);
        assertEq(treasuryOwed,0.00009 ether);assertEq(advisorOwed,0.00001 ether);
        uint256 founderBefore=founder.balance;uint256 advisorBefore=advisor.balance;
        hook.claimAdvisorFees();hook.claimTreasuryFees();
        assertEq(advisor.balance-advisorBefore,advisorOwed);assertEq(founder.balance-founderBefore,treasuryOwed);
        IAdminCalls.Call[] memory retire=new IAdminCalls.Call[](2);
        retire[0]=IAdminCalls.Call(address(next),0,abi.encodeCall(next.configure,(keeper,maxBatch,false)));
        retire[1]=IAdminCalls.Call(address(next),0,abi.encodeCall(next.recoverUnspentFees,(payable(OLD_VAULT),address(next).balance)));
        vm.prank(OPERATOR);IAdminCalls(administrator).execute(retire);
        calls=new IAdminCalls.Call[](3);
        calls[0]=IAdminCalls.Call(HOOK_ADMIN,0,abi.encodeWithSignature("upgradeAndCall(address,address,bytes)",HOOK,address(uint160(uint256(oldImplementation))),bytes("")));
        calls[1]=IAdminCalls.Call(HOOK,0,abi.encodeCall(hook.setLiquidityVault,(OLD_VAULT)));
        calls[2]=IAdminCalls.Call(OLD_VAULT,0,abi.encodeCall(old.configure,(keeper,maxBatch,true)));
        vm.prank(OPERATOR);IAdminCalls(administrator).execute(calls);
        assertEq(vm.load(HOOK,SLOT),oldImplementation);assertTrue(old.enabled());assertFalse(next.enabled());
        assertEq(hook.owner(),administrator);assertEq(hook.feePips(),20000);
        (share,destination,,)=hook.allocation();assertEq(share,500000);assertEq(destination,OLD_VAULT);
        p=plan(k,1);
        vm.prank(keeper);uint256 returnedBurn=old.buyAndBurn(p);
        assertGt(returnedBurn,0);assertEq(old.totalEthSpent(),oldSpent+0.00025 ether);
        assertEq(old.totalTokensBurned(),oldBurned+returnedBurn);
        assertEq(supply-ISupply(TOKEN).totalSupply(),newBurn+returnedBurn);
        assertEq(old.totalEthSpent()+next.totalEthSpent(),oldSpent+0.0005 ether);
        calls=new IAdminCalls.Call[](6);
        calls[0]=IAdminCalls.Call(OLD_VAULT,0,abi.encodeCall(old.configure,(keeper,maxBatch,false)));
        calls[1]=IAdminCalls.Call(HOOK_ADMIN,0,abi.encodeWithSignature("upgradeAndCall(address,address,bytes)",HOOK,implementation,bytes("")));
        calls[2]=IAdminCalls.Call(HOOK,0,abi.encodeCall(hook.initializeBuybackOracle,()));
        calls[3]=IAdminCalls.Call(HOOK,0,abi.encodeCall(hook.setLiquidityVault,(address(next))));
        calls[4]=IAdminCalls.Call(OLD_VAULT,0,abi.encodeCall(old.recoverUnspentFees,(payable(address(next)),OLD_VAULT.balance)));
        calls[5]=IAdminCalls.Call(address(next),0,abi.encodeCall(next.configure,(keeper,maxBatch,true)));
        vm.warp(block.timestamp+86400);
        vm.prank(OPERATOR);IAdminCalls(administrator).execute(calls);
        (ready,readyAt,,,observations)=hook.buybackOracleState();
        assertFalse(ready);assertEq(readyAt,block.timestamp+600);assertEq(observations,1);
        forkBlock++;
        vm.mockCall(address(100),abi.encodeWithSignature("arbBlockNumber()"),abi.encode(forkBlock));
        vm.mockCall(address(100),abi.encodeWithSignature("arbBlockHash(uint256)",forkBlock-1),abi.encode(keccak256("clock-only-test-stub")));
        p=plan(k,1);vm.prank(keeper);vm.expectRevert();next.buyAndBurn(p);
        vm.warp(block.timestamp+600);p=plan(k,uint128(hook.minimumBuybackOutput(0.00025 ether)));
        vm.prank(keeper);uint256 thirdBurn=next.buyAndBurn(p);assertGt(thirdBurn,0);
        assertEq(next.totalEthSpent(),0.0005 ether);assertEq(next.totalTokensBurned(),newBurn+thirdBurn);
        uint256 donation=ISupply(TOKEN).balanceOf(founder);if(donation>1 ether)donation=1 ether;assertGt(donation,0);
        vm.prank(founder);ISupply(TOKEN).transfer(address(next),donation);
        uint256 ethBefore=address(next).balance;
        calls=new IAdminCalls.Call[](1);calls[0]=IAdminCalls.Call(address(next),0,abi.encodeCall(next.burnDonatedTokens,()));
        vm.prank(OPERATOR);IAdminCalls(administrator).execute(calls);
        assertEq(ISupply(TOKEN).balanceOf(address(next)),0);assertEq(address(next).balance,ethBefore);
        assertEq(next.totalTokensBurned(),newBurn+thirdBurn);assertEq(next.totalDonatedTokensBurned(),donation);
        assertEq(supply-ISupply(TOKEN).totalSupply(),newBurn+returnedBurn+thirdBurn+donation);
    }
}

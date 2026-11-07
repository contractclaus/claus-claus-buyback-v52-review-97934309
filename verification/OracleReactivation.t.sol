// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {BuybackOracle} from '../flat/MigrationFeeHookV2.sol';

contract OracleHarness {
    BuybackOracle.State private state;
    function record(int24 tick,uint64 time) external {BuybackOracle.record(state,tick,time);}
    function reset(int24 tick,uint64 time) external {BuybackOracle.reset(state,tick,time);}
    function mean(uint64 time) external view returns(int24){return BuybackOracle.meanTick(state,time);}
    function minimum(uint128 input,uint64 time) external view returns(uint256){return BuybackOracle.minimumOutput(state,input,time);}
}
contract OracleReactivationTest {
    function test_reactivationDiscardsStaleTickAndRequiresFullWindow() public {
        OracleHarness h=new OracleHarness();
        h.record(0,1000);h.record(0,1700);
        // The old implementation can run and change price while no history is written.
        // A controlled reactivation resets at the newly observed live tick.
        h.reset(6932,88000);
        (bool ok,)=address(h).staticcall(abi.encodeCall(h.minimum,(1 ether,88599)));
        require(!ok,'Missing fresh warmup');
        require(h.mean(88600)==6932,'Stale tick survived reactivation');
        require(h.minimum(1 ether,88600)>1.98 ether,'Output floor used old history');
    }
    function test_resetDiscardsWrappedRingAndCumulative() public {
        OracleHarness h=new OracleHarness();
        for(uint64 i=0;i<1200;i++)h.record(10000,1000+i);
        h.reset(-90,100000);h.record(-60,100300);
        require(h.mean(100600)==-75,'Old cumulative survived ring reset');
    }
    function test_sameTimestampSpikeHasNoWeight() public {
        OracleHarness h=new OracleHarness();h.record(100,1000);h.record(800000,1600);
        require(h.mean(1600)==100,'Same-timestamp tick affected history');
    }
    function test_exactConstantPriceTolerance() public {
        OracleHarness h=new OracleHarness();h.record(0,1000);
        require(h.minimum(1 ether,1600)==0.995 ether,'Tolerance changed');
    }
}

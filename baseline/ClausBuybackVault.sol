// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
type Currency is address;
interface IHooks {}
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;
}
type PoolId is bytes32;
library PoolIdLibrary {
    function toId(PoolKey memory poolKey) internal pure returns (PoolId poolId) {
        assembly ("memory-safe") {
            poolId := keccak256(poolKey, 0xa0)
        }
    }
}
using PoolIdLibrary for PoolKey global;
interface IPoolManager {
    function extsload(bytes32 slot) external view returns (bytes32 value);
    function exttload(bytes32 slot) external view returns (bytes32 value);
}
library StateLibrary {
    bytes32 public constant POOLS_SLOT = bytes32(uint256(6));
    function getSlot0(IPoolManager manager, PoolId poolId)
        internal
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)
    {
        bytes32 stateSlot = keccak256(abi.encodePacked(PoolId.unwrap(poolId), POOLS_SLOT));
        bytes32 data = manager.extsload(stateSlot);
        assembly ("memory-safe") {
            sqrtPriceX96 := and(data, 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
            tick := signextend(2, shr(160, data))
            protocolFee := and(shr(184, data), 0xffffff)
            lpFee := and(shr(208, data), 0xffffff)
        }
    }
}
library TransientStateLibrary {
    bytes32 internal constant IS_UNLOCKED_SLOT = 0xc090fc4683624cfc3884e9d8de5eca132f2d0ec062aff75d43c0465d5ceeab23;
    function isUnlocked(IPoolManager manager) internal view returns (bool) {
        return manager.exttload(IS_UNLOCKED_SLOT) != 0x0;
    }
}
interface IV4Router {
    struct ExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        uint256 minHopPriceX36;
        bytes hookData;
    }
}
abstract contract Ownable is Context {
    address private _owner;
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }
    modifier onlyOwner() {
        _checkOwner();
        _;
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}
interface IClausFeeHook {
    function allocation() external view returns (uint24, address, uint256, uint256);
    function claimLiquidityFees() external;
    function claimTreasuryFees() external;
    function markBuyback() external;
}
interface IClausBurnable is IERC20 {
    function burn(uint256 amount) external;
}
interface IClausRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}
interface IClausClock {
    function arbBlockNumber() external view returns (uint256);
    function arbBlockHash(uint256 number) external view returns (bytes32);
}
contract ClausBuybackVault is Ownable2Step {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    IPoolManager public constant MANAGER = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);
    IClausRouter public constant ROUTER = IClausRouter(0x204FAca1764B154221e35c0d20aBb3c525710498);
    IClausClock private constant CLOCK = IClausClock(address(100));
    PoolKey public key;
    address public keeper;
    uint128 public maxBatch;
    bool public enabled;
    bool private busy;
    uint256 public totalEthSpent;
    uint256 public totalTokensBurned;

    struct Plan {
        uint128 amountIn;
        uint128 minBuyOutput;
        int24 quotedTick;
        uint24 maxTickDrift;
        uint256 quoteBlock;
        bytes32 quoteBlockHash;
        uint256 deadline;
    }

    event BuybackBurned(uint256 ethSpent, uint256 tokensBurned, uint256 supplyAfter);
    event AutomationConfigured(address keeper, uint128 maxBatch, bool enabled);
    event UnspentFeesRecovered(address indexed recipient, uint256 amount);

    constructor(address administrator, PoolKey memory pool, address initialKeeper, uint128 initialMaxBatch)
        Ownable(administrator)
    {
        require(block.chainid == 4663 && Currency.unwrap(pool.currency0) == address(0)
            && Currency.unwrap(pool.currency1).code.length != 0
            && address(pool.hooks).code.length != 0 && pool.tickSpacing > 0, "Invalid pool");
        key = pool;
        _configure(initialKeeper, initialMaxBatch, true);
    }

    modifier outsideSwap() {
        require(!busy && !MANAGER.isUnlocked(), "Busy");
        _;
    }

    function configure(address nextKeeper, uint128 nextMaxBatch, bool active) external onlyOwner outsideSwap {
        _configure(nextKeeper, nextMaxBatch, active);
    }

    function _configure(address nextKeeper, uint128 nextMaxBatch, bool active) private {
        require(!active || (nextKeeper != address(0) && nextMaxBatch > 0), "Invalid automation");
        keeper = nextKeeper;
        maxBatch = nextMaxBatch;
        enabled = active;
        emit AutomationConfigured(nextKeeper, nextMaxBatch, active);
    }

    function quoteAnchor() external view returns (uint256 number, bytes32 hash, uint256 timestamp) {
        number = CLOCK.arbBlockNumber() - 1;
        hash = CLOCK.arbBlockHash(number);
        timestamp = block.timestamp;
    }

    function buyAndBurn(Plan calldata p) external outsideSwap returns (uint256 burned) {
        require(enabled && (msg.sender == keeper || msg.sender == owner()), "Keeper only");
        require(p.amountIn > 0 && p.amountIn <= maxBatch && p.minBuyOutput > 0, "Invalid budget");
        uint256 currentBlock = CLOCK.arbBlockNumber();
        require(p.deadline >= block.timestamp && p.deadline <= block.timestamp + 120
            && p.quoteBlock < currentBlock && currentBlock - p.quoteBlock <= 128
            && p.quoteBlockHash != bytes32(0) && CLOCK.arbBlockHash(p.quoteBlock) == p.quoteBlockHash, "Stale plan");
        (, int24 tick,,) = MANAGER.getSlot0(key.toId());
        int256 drift = int256(tick) - p.quotedTick;
        if (drift < 0) drift = -drift;
        require(p.maxTickDrift <= 100 && uint256(drift) <= p.maxTickDrift, "Price moved");

        busy = true;
        IClausFeeHook hook = IClausFeeHook(address(key.hooks));
        (, address destination, uint256 owed,) = hook.allocation();
        require(destination == address(this), "Fee destination changed");
        if (owed > 0) hook.claimLiquidityFees();
        require(p.amountIn <= address(this).balance, "Insufficient fees");

        IClausBurnable token = IClausBurnable(Currency.unwrap(key.currency1));
        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 supplyBefore = token.totalSupply();
        bytes[] memory actions = new bytes[](3);
        actions[0] = abi.encode(IV4Router.ExactInputSingleParams(key, true, p.amountIn, p.minBuyOutput, 0, ""));
        actions[1] = abi.encode(address(0), uint256(p.amountIn));
        actions[2] = abi.encode(address(token), address(this), uint256(0));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(hex"060c0e", actions);
        ROUTER.execute{value:p.amountIn}(hex"10", inputs, p.deadline);
        burned = token.balanceOf(address(this)) - balanceBefore;
        require(burned >= p.minBuyOutput, "Insufficient output");
        token.burn(burned);
        require(token.balanceOf(address(this)) == balanceBefore
            && token.totalSupply() + burned == supplyBefore, "Burn mismatch");
        totalEthSpent += p.amountIn;
        totalTokensBurned += burned;

        (,,, uint256 treasuryOwed) = hook.allocation();
        if (treasuryOwed > 0) hook.claimTreasuryFees();
        busy = false;
        emit BuybackBurned(p.amountIn, burned, token.totalSupply());
    }

    // Only unspent fee funds belong to this contract. It never receives or
    // approves the existing LP positions or migration reserve.
    function recoverUnspentFees(address payable recipient, uint256 amount) external onlyOwner outsideSwap {
        require(recipient != address(0), "Invalid recipient");
        busy = true;
        (bool ok,) = recipient.call{value:amount}("");
        require(ok, "Recovery failed");
        busy = false;
        emit UnspentFeesRecovered(recipient, amount);
    }

    receive() external payable {}
}

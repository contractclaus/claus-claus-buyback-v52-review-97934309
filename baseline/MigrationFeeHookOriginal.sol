// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
type BeforeSwapDelta is int256;
function toBeforeSwapDelta(int128 deltaSpecified, int128 deltaUnspecified)
    pure
    returns (BeforeSwapDelta beforeSwapDelta)
{
    assembly ("memory-safe") {
        beforeSwapDelta := or(shl(128, deltaSpecified), and(sub(shl(128, 1), 1), deltaUnspecified))
    }
}
library BeforeSwapDeltaLibrary {
    BeforeSwapDelta public constant ZERO_DELTA = BeforeSwapDelta.wrap(0);
    function getSpecifiedDelta(BeforeSwapDelta delta) internal pure returns (int128 deltaSpecified) {
        assembly ("memory-safe") {
            deltaSpecified := sar(128, delta)
        }
    }
    function getUnspecifiedDelta(BeforeSwapDelta delta) internal pure returns (int128 deltaUnspecified) {
        assembly ("memory-safe") {
            deltaUnspecified := signextend(15, delta)
        }
    }
}
library CustomRevert {
    error WrappedError(address target, bytes4 selector, bytes reason, bytes details);
    function revertWith(bytes4 selector) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            revert(0, 0x04)
        }
    }
    function revertWith(bytes4 selector, address addr) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, and(addr, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(0, 0x24)
        }
    }
    function revertWith(bytes4 selector, int24 value) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, signextend(2, value))
            revert(0, 0x24)
        }
    }
    function revertWith(bytes4 selector, uint160 value) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, and(value, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(0, 0x24)
        }
    }
    function revertWith(bytes4 selector, int24 value1, int24 value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), signextend(2, value1))
            mstore(add(fmp, 0x24), signextend(2, value2))
            revert(fmp, 0x44)
        }
    }
    function revertWith(bytes4 selector, uint160 value1, uint160 value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), and(value1, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(fmp, 0x24), and(value2, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(fmp, 0x44)
        }
    }
    function revertWith(bytes4 selector, address value1, address value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), and(value1, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(fmp, 0x24), and(value2, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(fmp, 0x44)
        }
    }
    function bubbleUpAndRevertWith(
        address revertingContract,
        bytes4 revertingFunctionSelector,
        bytes4 additionalContext
    ) internal pure {
        bytes4 wrappedErrorSelector = WrappedError.selector;
        assembly ("memory-safe") {
            let encodedDataSize := mul(div(add(returndatasize(), 31), 32), 32)
            let fmp := mload(0x40)
            mstore(fmp, wrappedErrorSelector)
            mstore(add(fmp, 0x04), and(revertingContract, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(
                add(fmp, 0x24),
                and(revertingFunctionSelector, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            )
            mstore(add(fmp, 0x44), 0x80)
            mstore(add(fmp, 0x64), add(0xa0, encodedDataSize))
            mstore(add(fmp, 0x84), returndatasize())
            returndatacopy(add(fmp, 0xa4), 0, returndatasize())
            mstore(add(fmp, add(0xa4, encodedDataSize)), 0x04)
            mstore(
                add(fmp, add(0xc4, encodedDataSize)),
                and(additionalContext, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            )
            revert(fmp, add(0xe4, encodedDataSize))
        }
    }
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
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
interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC6909Claims {
    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);
    function balanceOf(address owner, uint256 id) external view returns (uint256 amount);
    function allowance(address owner, address spender, uint256 id) external view returns (uint256 amount);
    function isOperator(address owner, address spender) external view returns (bool approved);
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);
    function setOperator(address operator, bool approved) external returns (bool);
}
interface IExtsload {
    function extsload(bytes32 slot) external view returns (bytes32 value);
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory values);
    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory values);
}
interface IExttload {
    function exttload(bytes32 slot) external view returns (bytes32 value);
    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory values);
}
abstract contract Initializable {
    struct InitializableStorage {
        uint64 _initialized;
        bool _initializing;
    }
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    error InvalidInitialization();
    error NotInitializing();
    event Initialized(uint64 version);
    modifier initializer() {
        InitializableStorage storage $ = _getInitializableStorage();
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;
        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }
    modifier reinitializer(uint64 version) {
        InitializableStorage storage $ = _getInitializableStorage();
        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }
    function _disableInitializers() internal virtual {
        InitializableStorage storage $ = _getInitializableStorage();
        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}
library Lock {
    bytes32 internal constant IS_UNLOCKED_SLOT = 0xc090fc4683624cfc3884e9d8de5eca132f2d0ec062aff75d43c0465d5ceeab23;
    function unlock() internal {
        assembly ("memory-safe") {
            tstore(IS_UNLOCKED_SLOT, true)
        }
    }
    function lock() internal {
        assembly ("memory-safe") {
            tstore(IS_UNLOCKED_SLOT, false)
        }
    }
    function isUnlocked() internal view returns (bool unlocked) {
        assembly ("memory-safe") {
            unlocked := tload(IS_UNLOCKED_SLOT)
        }
    }
}
library NonzeroDeltaCount {
    bytes32 internal constant NONZERO_DELTA_COUNT_SLOT =
        0x7d4b3164c6e45b97e7d87b7125a44c5828d005af88f9d751cfd78729c5d99a0b;
    function read() internal view returns (uint256 count) {
        assembly ("memory-safe") {
            count := tload(NONZERO_DELTA_COUNT_SLOT)
        }
    }
    function increment() internal {
        assembly ("memory-safe") {
            let count := tload(NONZERO_DELTA_COUNT_SLOT)
            count := add(count, 1)
            tstore(NONZERO_DELTA_COUNT_SLOT, count)
        }
    }
    function decrement() internal {
        assembly ("memory-safe") {
            let count := tload(NONZERO_DELTA_COUNT_SLOT)
            count := sub(count, 1)
            tstore(NONZERO_DELTA_COUNT_SLOT, count)
        }
    }
}
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }
    function __Context_init_unchained() internal onlyInitializing {
    }
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
library SafeCast {
    using CustomRevert for bytes4;
    error SafeCastOverflow();
    function toUint160(uint256 x) internal pure returns (uint160 y) {
        y = uint160(x);
        if (y != x) SafeCastOverflow.selector.revertWith();
    }
    function toUint128(uint256 x) internal pure returns (uint128 y) {
        y = uint128(x);
        if (x != y) SafeCastOverflow.selector.revertWith();
    }
    function toUint128(int128 x) internal pure returns (uint128 y) {
        if (x < 0) SafeCastOverflow.selector.revertWith();
        y = uint128(x);
    }
    function toInt128(int256 x) internal pure returns (int128 y) {
        y = int128(x);
        if (y != x) SafeCastOverflow.selector.revertWith();
    }
    function toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        if (y < 0) SafeCastOverflow.selector.revertWith();
    }
    function toInt128(uint256 x) internal pure returns (int128) {
        if (x >= 1 << 127) SafeCastOverflow.selector.revertWith();
        return int128(int256(x));
    }
}
type BalanceDelta is int256;
using {add as +, sub as -, eq as ==, neq as !=} for BalanceDelta global;
using BalanceDeltaLibrary for BalanceDelta global;
using SafeCast for int256;
function toBalanceDelta(int128 _amount0, int128 _amount1) pure returns (BalanceDelta balanceDelta) {
    assembly ("memory-safe") {
        balanceDelta := or(shl(128, _amount0), and(sub(shl(128, 1), 1), _amount1))
    }
}
function add(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
    int256 res0;
    int256 res1;
    assembly ("memory-safe") {
        let a0 := sar(128, a)
        let a1 := signextend(15, a)
        let b0 := sar(128, b)
        let b1 := signextend(15, b)
        res0 := add(a0, b0)
        res1 := add(a1, b1)
    }
    return toBalanceDelta(res0.toInt128(), res1.toInt128());
}
function sub(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
    int256 res0;
    int256 res1;
    assembly ("memory-safe") {
        let a0 := sar(128, a)
        let a1 := signextend(15, a)
        let b0 := sar(128, b)
        let b1 := signextend(15, b)
        res0 := sub(a0, b0)
        res1 := sub(a1, b1)
    }
    return toBalanceDelta(res0.toInt128(), res1.toInt128());
}
function eq(BalanceDelta a, BalanceDelta b) pure returns (bool) {
    return BalanceDelta.unwrap(a) == BalanceDelta.unwrap(b);
}
function neq(BalanceDelta a, BalanceDelta b) pure returns (bool) {
    return BalanceDelta.unwrap(a) != BalanceDelta.unwrap(b);
}
library BalanceDeltaLibrary {
    BalanceDelta public constant ZERO_DELTA = BalanceDelta.wrap(0);
    function amount0(BalanceDelta balanceDelta) internal pure returns (int128 _amount0) {
        assembly ("memory-safe") {
            _amount0 := sar(128, balanceDelta)
        }
    }
    function amount1(BalanceDelta balanceDelta) internal pure returns (int128 _amount1) {
        assembly ("memory-safe") {
            _amount1 := signextend(15, balanceDelta)
        }
    }
}
type Currency is address;
using {greaterThan as >, lessThan as <, greaterThanOrEqualTo as >=, equals as ==} for Currency global;
using CurrencyLibrary for Currency global;
function equals(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) == Currency.unwrap(other);
}
function greaterThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) > Currency.unwrap(other);
}
function lessThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) < Currency.unwrap(other);
}
function greaterThanOrEqualTo(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) >= Currency.unwrap(other);
}
library CurrencyLibrary {
    error NativeTransferFailed();
    error ERC20TransferFailed();
    Currency public constant ADDRESS_ZERO = Currency.wrap(address(0));
    function transfer(Currency currency, address to, uint256 amount) internal {
        bool success;
        if (currency.isAddressZero()) {
            assembly ("memory-safe") {
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }
            if (!success) {
                CustomRevert.bubbleUpAndRevertWith(to, bytes4(0), NativeTransferFailed.selector);
            }
        } else {
            assembly ("memory-safe") {
                let fmp := mload(0x40)
                mstore(fmp, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(fmp, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(fmp, 36), amount)
                success :=
                    and(
                        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                        call(gas(), currency, 0, fmp, 68, 0, 32)
                    )
                mstore(fmp, 0)
                mstore(add(fmp, 0x20), 0)
                mstore(add(fmp, 0x40), 0)
            }
            if (!success) {
                CustomRevert.bubbleUpAndRevertWith(
                    Currency.unwrap(currency), IERC20Minimal.transfer.selector, ERC20TransferFailed.selector
                );
            }
        }
    }
    function balanceOfSelf(Currency currency) internal view returns (uint256) {
        if (currency.isAddressZero()) {
            return address(this).balance;
        } else {
            return IERC20Minimal(Currency.unwrap(currency)).balanceOf(address(this));
        }
    }
    function balanceOf(Currency currency, address owner) internal view returns (uint256) {
        if (currency.isAddressZero()) {
            return owner.balance;
        } else {
            return IERC20Minimal(Currency.unwrap(currency)).balanceOf(owner);
        }
    }
    function isAddressZero(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == Currency.unwrap(ADDRESS_ZERO);
    }
    function toId(Currency currency) internal pure returns (uint256) {
        return uint160(Currency.unwrap(currency));
    }
    function fromId(uint256 id) internal pure returns (Currency) {
        return Currency.wrap(address(uint160(id)));
    }
}
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    struct OwnableStorage {
        address _owner;
    }
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;
    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }
    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
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
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
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
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
library CurrencyReserves {
    using CustomRevert for bytes4;
    bytes32 constant RESERVES_OF_SLOT = 0x1e0745a7db1623981f0b2a5d4232364c00787266eb75ad546f190e6cebe9bd95;
    bytes32 constant CURRENCY_SLOT = 0x27e098c505d44ec3574004bca052aabf76bd35004c182099d8c575fb238593b9;
    function getSyncedCurrency() internal view returns (Currency currency) {
        assembly ("memory-safe") {
            currency := tload(CURRENCY_SLOT)
        }
    }
    function resetCurrency() internal {
        assembly ("memory-safe") {
            tstore(CURRENCY_SLOT, 0)
        }
    }
    function syncCurrencyAndReserves(Currency currency, uint256 value) internal {
        assembly ("memory-safe") {
            tstore(CURRENCY_SLOT, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
            tstore(RESERVES_OF_SLOT, value)
        }
    }
    function getSyncedReserves() internal view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(RESERVES_OF_SLOT)
        }
    }
}
abstract contract Ownable2StepUpgradeable is Initializable, OwnableUpgradeable {
    struct Ownable2StepStorage {
        address _pendingOwner;
    }
    bytes32 private constant Ownable2StepStorageLocation = 0x237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c00;
    function _getOwnable2StepStorage() private pure returns (Ownable2StepStorage storage $) {
        assembly {
            $.slot := Ownable2StepStorageLocation
        }
    }
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    function __Ownable2Step_init() internal onlyInitializing {
    }
    function __Ownable2Step_init_unchained() internal onlyInitializing {
    }
    function pendingOwner() public view virtual returns (address) {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        return $._pendingOwner;
    }
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        $._pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual override {
        Ownable2StepStorage storage $ = _getOwnable2StepStorage();
        delete $._pendingOwner;
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
interface IHooks {
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96) external returns (bytes4);
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        returns (bytes4);
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4);
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4);
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);
    function beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        returns (bytes4, BeforeSwapDelta, uint24);
    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128);
    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4);
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4);
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
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;
}
struct ModifyLiquidityParams {
    int24 tickLower;
    int24 tickUpper;
    int256 liquidityDelta;
    bytes32 salt;
}
struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}
interface IProtocolFees {
    error ProtocolFeeTooLarge(uint24 fee);
    error InvalidCaller();
    error ProtocolFeeCurrencySynced();
    event ProtocolFeeControllerUpdated(address indexed protocolFeeController);
    event ProtocolFeeUpdated(PoolId indexed id, uint24 protocolFee);
    function protocolFeesAccrued(Currency currency) external view returns (uint256 amount);
    function setProtocolFee(PoolKey memory key, uint24 newProtocolFee) external;
    function setProtocolFeeController(address controller) external;
    function collectProtocolFees(address recipient, Currency currency, uint256 amount)
        external
        returns (uint256 amountCollected);
    function protocolFeeController() external view returns (address);
}
interface IHookStats is IERC165 {
    function getReserves(PoolKey calldata key) external view returns (uint256 amount0, uint256 amount1);
    function getEffectiveLiquidity(PoolKey calldata key) external view returns (uint256 amount0, uint256 amount1);
    function hook() external view returns (address);
}
interface IPoolManager is IProtocolFees, IERC6909Claims, IExtsload, IExttload {
    error CurrencyNotSettled();
    error PoolNotInitialized();
    error AlreadyUnlocked();
    error ManagerLocked();
    error TickSpacingTooLarge(int24 tickSpacing);
    error TickSpacingTooSmall(int24 tickSpacing);
    error CurrenciesOutOfOrderOrEqual(address currency0, address currency1);
    error UnauthorizedDynamicLPFeeUpdate();
    error SwapAmountCannotBeZero();
    error NonzeroNativeValue();
    error MustClearExactPositiveDelta();
    event Initialize(
        PoolId indexed id,
        Currency indexed currency0,
        Currency indexed currency1,
        uint24 fee,
        int24 tickSpacing,
        IHooks hooks,
        uint160 sqrtPriceX96,
        int24 tick
    );
    event ModifyLiquidity(
        PoolId indexed id, address indexed sender, int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes32 salt
    );
    event Swap(
        PoolId indexed id,
        address indexed sender,
        int128 amount0,
        int128 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick,
        uint24 fee
    );
    event Donate(PoolId indexed id, address indexed sender, uint256 amount0, uint256 amount1);
    function unlock(bytes calldata data) external returns (bytes memory);
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick);
    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta callerDelta, BalanceDelta feesAccrued);
    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta swapDelta);
    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        returns (BalanceDelta);
    function sync(Currency currency) external;
    function take(Currency currency, address to, uint256 amount) external;
    function settle() external payable returns (uint256 paid);
    function settleFor(address recipient) external payable returns (uint256 paid);
    function clear(Currency currency, uint256 amount) external;
    function mint(address to, uint256 id, uint256 amount) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external;
}
library TransientStateLibrary {
    function getSyncedReserves(IPoolManager manager) internal view returns (uint256) {
        if (getSyncedCurrency(manager).isAddressZero()) return 0;
        return uint256(manager.exttload(CurrencyReserves.RESERVES_OF_SLOT));
    }
    function getSyncedCurrency(IPoolManager manager) internal view returns (Currency) {
        return Currency.wrap(address(uint160(uint256(manager.exttload(CurrencyReserves.CURRENCY_SLOT)))));
    }
    function getNonzeroDeltaCount(IPoolManager manager) internal view returns (uint256) {
        return uint256(manager.exttload(NonzeroDeltaCount.NONZERO_DELTA_COUNT_SLOT));
    }
    function currencyDelta(IPoolManager manager, address target, Currency currency) internal view returns (int256) {
        bytes32 key;
        assembly ("memory-safe") {
            mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
            key := keccak256(0, 64)
        }
        return int256(uint256(manager.exttload(key)));
    }
    function isUnlocked(IPoolManager manager) internal view returns (bool) {
        return manager.exttload(Lock.IS_UNLOCKED_SLOT) != 0x0;
    }
}
contract MigrationFeeHookOriginal is Ownable2StepUpgradeable, IHooks, IHookStats {
    using SafeCast for uint256;
    using TransientStateLibrary for IPoolManager;

    IPoolManager public constant MANAGER = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);
    uint24 public constant DENOMINATOR = 1_000_000;
    struct Settings {
        address token;
        address launcher;
        address recipient;
        uint160 openingPrice;
        int24 spacing;
        uint24 feePips;
        bool launched;
        bytes32 poolId;
    }
    bytes32 private constant SETTINGS_SLOT = keccak256("test.hook.settings.v1");
    error InvalidPool();
    error InvalidFee();
    error InvalidCaller();
    error PartialFill();
    event FeeChanged(uint24 previousPips, uint24 feePips);
    event FeeRecipientChanged(address indexed recipient);
    event LaunchConfigured(address indexed launcher, uint160 openingPrice);
    event SwapFee(bytes32 indexed poolId, address indexed sender, bool buy, uint256 grossEth, uint256 feeEth);
    // URC-2: only the custom-accounting contribution, in pool currency order.
    event HookSwap(PoolId indexed id, address indexed sender, int128 amount0, int128 amount1, uint24 swapFee);
    event FeesClaimed(address indexed recipient, uint256 amount);

    constructor() { _disableInitializers(); }

    modifier onlyManager() { if (msg.sender != address(MANAGER)) revert InvalidCaller(); _; }
    modifier outsideSwap() { if (MANAGER.isUnlocked()) revert InvalidCaller(); _; }

    function initialize(address administrator, address token_, address launcher_, uint160 price, int24 spacing)
        external initializer
    {
        require(token_.code.length != 0 && launcher_ != address(0) && price != 0 && spacing > 0);
        __Ownable_init(administrator);
        __Ownable2Step_init();
        Settings storage s = _settings();
        s.token = token_; s.launcher = launcher_; s.recipient = administrator;
        s.openingPrice = price; s.spacing = spacing; s.feePips = 20_000;
        _allocation().liquiditySharePips = 500_000;
    }

    function feePips() external view returns (uint24) { return _settings().feePips; }
    function feeRecipient() external view returns (address) { return _settings().recipient; }
    function poolId() external view returns (bytes32) { return _settings().poolId; }
    function launched() external view returns (bool) { return _settings().launched; }
    function token() external view returns (address) { return _settings().token; }
    function hook() external view returns (address) { return address(this); }

    function setFee(uint24 value) external onlyOwner outsideSwap {
        // 100% has no finite exact-output quote; every lower rate is representable.
        if (value >= DENOMINATOR) revert InvalidFee();
        Settings storage s = _settings();
        emit FeeChanged(s.feePips, value); s.feePips = value;
    }

    function setFeeRecipient(address value) external onlyOwner outsideSwap {
        require(value != address(0));
        emit AccruedFeesRedirected(false,_settings().recipient,value,_allocation().treasuryOwed);
        _settings().recipient = value; emit FeeRecipientChanged(value);
    }

    function configureLaunch(address launcher_, uint160 price) external onlyOwner outsideSwap {
        Settings storage s = _settings();
        require(!s.launched && launcher_ != address(0) && price != 0);
        s.launcher = launcher_; s.openingPrice = price;
        emit LaunchConfigured(launcher_, price);
    }

    function beforeInitialize(address sender, PoolKey calldata key, uint160 price)
        external onlyManager returns (bytes4)
    {
        Settings storage s = _settings();
        if (s.launched || sender != s.launcher || price != s.openingPrice
            || Currency.unwrap(key.currency0) != address(0) || Currency.unwrap(key.currency1) != s.token
            || address(key.hooks) != address(this) || key.fee != 0x800000 || key.tickSpacing != s.spacing)
            revert InvalidPool();
        s.launched = true; s.poolId = PoolId.unwrap(key.toId());
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata key, uint160, int24)
        external onlyManager returns (bytes4)
    {
        _checkPool(key); MANAGER.updateDynamicLPFee(key, 0);
        return IHooks.afterInitialize.selector;
    }

    function beforeSwap(address, PoolKey calldata key, SwapParams calldata p, bytes calldata)
        external onlyManager returns (bytes4, BeforeSwapDelta, uint24)
    {
        _checkPool(key);
        uint256 fee;
        if (_nativeSpecified(p)) {
            uint256 requested = _specified(p);
            fee = p.amountSpecified < 0 ? _grossFee(requested) : _netFee(requested);
        }
        return (IHooks.beforeSwap.selector, toBeforeSwapDelta(fee.toInt128(), 0), 0x400000);
    }

    function afterSwap(address sender, PoolKey calldata key, SwapParams calldata p, BalanceDelta delta, bytes calldata)
        external onlyManager returns (bytes4, int128 returnedFee)
    {
        _checkPool(key);
        bool exactInput = p.amountSpecified < 0;
        if (!exactInput && p.zeroForOne && int256(delta.amount1()) != p.amountSpecified) revert PartialFill();
        int128 ethDelta = delta.amount0();
        uint256 nativeAmount = ethDelta < 0 ? uint256(-int256(ethDelta)) : uint256(int256(ethDelta));
        uint256 fee; uint256 gross;
        if (_nativeSpecified(p)) {
            uint256 requested = _specified(p);
            fee = exactInput ? _grossFee(requested) : _netFee(requested);
            uint256 expected = exactInput ? requested - fee : requested + fee;
            if (nativeAmount != expected) revert PartialFill();
            gross = exactInput ? requested : expected;
        } else {
            fee = exactInput ? _grossFee(nativeAmount) : _netFee(nativeAmount);
            gross = exactInput ? nativeAmount : nativeAmount + fee;
            returnedFee = fee.toInt128();
        }
        if (fee != 0) {
            MANAGER.mint(address(this), 0, fee);
            Allocation storage a=_allocation();
            uint256 lp=fee*a.liquiditySharePips/DENOMINATOR;
            a.liquidityOwed+=lp;a.treasuryOwed+=fee-lp;
            emit FeeAllocated(lp,fee-lp);
            emit HookSwap(key.toId(), sender, -fee.toInt128(), 0, _settings().feePips);
        }
        emit SwapFee(_settings().poolId, sender, p.zeroForOne, gross, fee);
        return (IHooks.afterSwap.selector, returnedFee);
    }

    // Accrual remains internal to the hook. No router, keeper, recipient or
    // liquidity vault is called inside a user's swap.
    struct Allocation {uint24 liquiditySharePips;address vault;uint256 liquidityOwed;uint256 treasuryOwed;}
    bytes32 private constant ALLOCATION_SLOT=keccak256("claus.migration.fee-allocation.v1");
    event FeeAllocated(uint256 liquidity,uint256 treasury);
    event AllocationChanged(uint24 liquiditySharePips,address vault);
    event AccruedFeesRedirected(bool liquidity,address previous,address destination,uint256 accrued);
    function allocation() external view returns(uint24,address,uint256,uint256){
        Allocation storage a=_allocation();return(a.liquiditySharePips,a.vault,a.liquidityOwed,a.treasuryOwed);
    }
    function setLiquidityShare(uint24 share) external onlyOwner outsideSwap {
        require(share<=DENOMINATOR);_allocation().liquiditySharePips=share;
        emit AllocationChanged(share,_allocation().vault);
    }
    function setLiquidityVault(address vault) external onlyOwner outsideSwap {
        require(vault.code.length!=0);
        emit AccruedFeesRedirected(true,_allocation().vault,vault,_allocation().liquidityOwed);
        _allocation().vault=vault;emit AllocationChanged(_allocation().liquiditySharePips,vault);
    }
    function claimLiquidityFees() external outsideSwap {
        Allocation storage a=_allocation();uint256 amount=a.liquidityOwed;
        require(a.vault!=address(0) && amount!=0);a.liquidityOwed=0;
        MANAGER.unlock(abi.encode(amount,a.vault));
    }
    function claimTreasuryFees() external outsideSwap {
        Allocation storage a=_allocation();uint256 amount=a.treasuryOwed;
        require(amount!=0);a.treasuryOwed=0;
        MANAGER.unlock(abi.encode(amount,_settings().recipient));
    }
    function unlockCallback(bytes calldata data) external onlyManager returns(bytes memory){
        (uint256 amount,address recipient)=abi.decode(data,(uint256,address));
        MANAGER.burn(address(this),0,amount);MANAGER.take(Currency.wrap(address(0)),recipient,amount);
        emit FeesClaimed(recipient,amount);return "";
    }
    function _allocation() private pure returns(Allocation storage a){bytes32 slot=ALLOCATION_SLOT;assembly{a.slot:=slot}}

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IHookStats).interfaceId;
    }
    function getReserves(PoolKey calldata key) external view returns (uint256, uint256) {
        _checkPool(key);
        return (address(this).balance + MANAGER.balanceOf(address(this), 0),
            IERC20(_settings().token).balanceOf(address(this))
                + MANAGER.balanceOf(address(this), uint256(uint160(_settings().token))));
    }
    function getEffectiveLiquidity(PoolKey calldata key) external view returns (uint256, uint256) {
        _checkPool(key); return (0, 0);
    }

    function beforeAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        external onlyManager returns (bytes4) { _checkPool(key); return IHooks.beforeAddLiquidity.selector; }
    function afterAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata)
        external onlyManager returns (bytes4, BalanceDelta) { _checkPool(key); return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0)); }
    function beforeRemoveLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        external onlyManager returns (bytes4) { _checkPool(key); return IHooks.beforeRemoveLiquidity.selector; }
    function afterRemoveLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata)
        external onlyManager returns (bytes4, BalanceDelta) { _checkPool(key); return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0)); }
    function beforeDonate(address, PoolKey calldata key, uint256, uint256, bytes calldata)
        external onlyManager returns (bytes4) { _checkPool(key); return IHooks.beforeDonate.selector; }
    function afterDonate(address, PoolKey calldata key, uint256, uint256, bytes calldata)
        external onlyManager returns (bytes4) { _checkPool(key); return IHooks.afterDonate.selector; }

    function _grossFee(uint256 gross) private view returns (uint256) { return gross * _settings().feePips / DENOMINATOR; }
    function _netFee(uint256 net) private view returns (uint256) {
        uint256 rate = _settings().feePips;
        return net * rate / (DENOMINATOR - rate);
    }
    function _nativeSpecified(SwapParams calldata p) private pure returns (bool) { return (p.amountSpecified < 0) == p.zeroForOne; }
    function _specified(SwapParams calldata p) private pure returns (uint256) {
        return p.amountSpecified < 0 ? uint256(-(p.amountSpecified + 1)) + 1 : uint256(p.amountSpecified);
    }
    function _checkPool(PoolKey calldata key) private view {
        if (!_settings().launched || PoolId.unwrap(key.toId()) != _settings().poolId) revert InvalidPool();
    }
    function _settings() private pure returns (Settings storage s) {
        bytes32 slot = SETTINGS_SLOT;
        assembly { s.slot := slot }
    }
}

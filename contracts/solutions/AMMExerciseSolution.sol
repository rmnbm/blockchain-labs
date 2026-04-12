// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import "@uniswap/v4-core/src/libraries/TickMath.sol";
import "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";
import "@uniswap/v4-core/src/types/PoolId.sol" as PoolIds;
import "@uniswap/v4-core/src/types/PoolOperation.sol";
import "@uniswap/v4-core/src/types/BalanceDelta.sol";
import "./../IExerciceSolution.sol";
import "./../interfaces/IStateView.sol";
import "./../interfaces/IPositionManagerExtended.sol";
import "./../interfaces/IPermit2AllowanceTransfer.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @title AMMExerciseSolution
/// @notice Stateful Uniswap v4 integration contract for AMM 101.
contract AMMExerciseSolution is IExerciceSolution, IUnlockCallback {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    uint24 private constant POOL_FEE = 500;
    int24 private constant TICK_LOWER = -600;
    int24 private constant TICK_UPPER = 600;

    uint8 private constant ACTION_MINT_POSITION = 0x02;
    uint8 private constant ACTION_DECREASE_LIQUIDITY = 0x01;
    uint8 private constant ACTION_SETTLE_PAIR = 0x0d;
    uint8 private constant ACTION_TAKE_PAIR = 0x11;
    uint8 private constant ACTION_SWEEP = 0x14;

    uint8 private constant OP_SWAP_TOKEN_FOR_ETH = 1;
    uint8 private constant OP_SWAP_ETH_FOR_DUMMY = 2;
    uint8 private constant OP_SWAP_ETH_FOR_STUDENT_TOKEN = 3;

    IERC20 public immutable yourToken;
    IERC20 public immutable dummyToken;
    IPositionManagerExtended public immutable positionManager;
    IStateView public immutable stateView;
    IPoolManager public immutable poolManager;
    address public immutable owner;

    uint256 public bootstrapPositionId;
    uint256 public exercisePositionId;
    bool public exerciseLiquidityIsOpen;

    uint256 public exerciseLiquidity;
    uint128 public exerciseEthMax;
    uint128 public exerciseTokenMax;

    error NotOwner(address caller);
    error UnexpectedPoolManager(address caller);
    error ZeroAmount();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    constructor(
        address yourTokenAddress,
        address dummyTokenAddress,
        address positionManagerAddress,
        address stateViewAddress
    ) {
        yourToken = IERC20(yourTokenAddress);
        dummyToken = IERC20(dummyTokenAddress);
        positionManager = IPositionManagerExtended(positionManagerAddress);
        stateView = IStateView(stateViewAddress);
        poolManager = IPoolManager(positionManager.poolManager());
        owner = msg.sender;

        _setupPermit2Approval(yourTokenAddress);
    }

    receive() external payable {}

    function configureExerciseLiquidity(
        uint256 liquidity,
        uint128 ethAmountMax,
        uint128 tokenAmountMax
    ) external onlyOwner {
        exerciseLiquidity = liquidity;
        exerciseEthMax = ethAmountMax;
        exerciseTokenMax = tokenAmountMax;
    }

    function bootstrapPoolAndLiquidity(
        uint160 sqrtPriceX96,
        uint256 liquidity,
        uint128 ethAmountMax,
        uint128 tokenAmountMax
    ) external onlyOwner {
        poolManager.initialize(_studentPoolKey(), sqrtPriceX96);
        bootstrapPositionId = _mintStudentPosition(
            liquidity,
            ethAmountMax,
            tokenAmountMax
        );
    }

    function buyDummyForOwner(uint128 ethAmountIn) external onlyOwner {
        uint256 dummyBefore = dummyToken.balanceOf(address(this));
        _swapExactIn(OP_SWAP_ETH_FOR_DUMMY, ethAmountIn);
        uint256 dummyAcquired = dummyToken.balanceOf(address(this)) - dummyBefore;
        require(dummyToken.transfer(owner, dummyAcquired), "Dummy transfer failed");
    }

    function addLiquidity() external override {
        if (!exerciseLiquidityIsOpen) {
            _ensurePoolPriceCanTakeLiquidity();
            exercisePositionId = _mintStudentPositionDynamic(
                exerciseLiquidity,
                exerciseEthMax,
                exerciseTokenMax
            );
            exerciseLiquidityIsOpen = true;
            return;
        }

        _decreaseStudentPosition(exercisePositionId);
        exerciseLiquidityIsOpen = false;
    }

    function withdrawLiquidity() external override {
        _decreaseStudentPosition(exercisePositionId);
        exerciseLiquidityIsOpen = false;
    }

    function swapYourTokenForDummyToken() external override {
        _swapExactIn(OP_SWAP_TOKEN_FOR_ETH, _boundedTokenInput());
        _swapExactIn(OP_SWAP_ETH_FOR_DUMMY, _boundedEthInput());
    }

    function swapYourTokenForEth() external override {
        _swapExactIn(OP_SWAP_TOKEN_FOR_ETH, _boundedTokenInput());
    }

    function unlockCallback(
        bytes calldata data
    ) external override returns (bytes memory) {
        if (msg.sender != address(poolManager)) {
            revert UnexpectedPoolManager(msg.sender);
        }

        (uint8 operation, uint128 amountIn) = abi.decode(data, (uint8, uint128));

        if (operation == OP_SWAP_TOKEN_FOR_ETH) {
            _executeTokenForEthSwap(amountIn);
            return "";
        }

        if (operation == OP_SWAP_ETH_FOR_DUMMY) {
            _executeEthForDummySwap(amountIn);
            return "";
        }

        if (operation == OP_SWAP_ETH_FOR_STUDENT_TOKEN) {
            _executeEthForStudentTokenSwap(amountIn);
            return "";
        }

        revert("Unsupported operation");
    }

    function rescueToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function rescueEth(address payable to, uint256 amount) external onlyOwner {
        to.transfer(amount);
    }

    function _mintStudentPosition(
        uint256 liquidity,
        uint128 ethAmountMax,
        uint128 tokenAmountMax
    ) internal returns (uint256 tokenId) {
        if (liquidity == 0 || ethAmountMax == 0 || tokenAmountMax == 0) {
            revert ZeroAmount();
        }

        PoolKey memory key = _studentPoolKey();
        tokenId = positionManager.nextTokenId();

        bytes memory actions = abi.encodePacked(
            bytes1(ACTION_MINT_POSITION),
            bytes1(ACTION_SETTLE_PAIR),
            bytes1(ACTION_SWEEP)
        );
        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            key,
            TICK_LOWER,
            TICK_UPPER,
            liquidity,
            ethAmountMax,
            tokenAmountMax,
            address(this),
            new bytes(0)
        );
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(this));

        positionManager.modifyLiquidities{value: ethAmountMax}(
            abi.encode(actions, params),
            block.timestamp
        );
    }

    function _decreaseStudentPosition(uint256 tokenId) internal {
        uint128 liquidity = positionManager.getPositionLiquidity(tokenId);
        require(liquidity > 0, "No liquidity left");

        PoolKey memory key = _studentPoolKey();
        bytes memory actions = abi.encodePacked(
            bytes1(ACTION_DECREASE_LIQUIDITY),
            bytes1(ACTION_TAKE_PAIR)
        );
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, liquidity, 0, 0, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1, address(this));

        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            block.timestamp
        );
    }

    function _swapExactIn(uint8 operation, uint128 amountIn) internal {
        if (amountIn == 0) {
            revert ZeroAmount();
        }

        poolManager.unlock(abi.encode(operation, amountIn));
    }

    function _executeTokenForEthSwap(uint128 amountIn) internal {
        PoolKey memory key = _studentPoolKey();
        BalanceDelta delta = poolManager.swap(
            key,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -int256(uint256(amountIn)),
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            new bytes(0)
        );

        _settleOrTake(key.currency0, delta.amount0());
        _settleOrTake(key.currency1, delta.amount1());
    }

    function _executeEthForDummySwap(uint128 amountIn) internal {
        PoolKey memory key = _dummyPoolKey();
        BalanceDelta delta = poolManager.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(uint256(amountIn)),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            new bytes(0)
        );

        _settleOrTake(key.currency0, delta.amount0());
        _settleOrTake(key.currency1, delta.amount1());
    }

    function _executeEthForStudentTokenSwap(uint128 amountIn) internal {
        PoolKey memory key = _studentPoolKey();
        BalanceDelta delta = poolManager.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(uint256(amountIn)),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            new bytes(0)
        );

        _settleOrTake(key.currency0, delta.amount0());
        _settleOrTake(key.currency1, delta.amount1());
    }

    function _ensurePoolPriceCanTakeLiquidity() internal {
        PoolId poolId = _studentPoolKey().toId();
        (, int24 currentTick, , ) = stateView.getSlot0(poolId);

        if (currentTick >= TickMath.MAX_TICK - 1) {
            _swapExactIn(
                OP_SWAP_ETH_FOR_STUDENT_TOKEN,
                uint128(address(this).balance / 5)
            );
        }
    }

    function _mintStudentPositionDynamic(
        uint256 liquidity,
        uint128 ethAmountMax,
        uint128 tokenAmountMax
    ) internal returns (uint256 tokenId) {
        PoolId poolId = _studentPoolKey().toId();
        (, int24 currentTick, , ) = stateView.getSlot0(poolId);
        int24 tickSpacing = int24((POOL_FEE / 100) * 2);
        int24 lower = _boundTick(
            _alignTick(currentTick - 600, tickSpacing),
            tickSpacing
        );
        int24 upper = _boundTick(
            _alignTick(currentTick + 600, tickSpacing),
            tickSpacing
        );

        if (lower >= upper) {
            lower = _boundTick(_alignTick(currentTick - tickSpacing, tickSpacing), tickSpacing);
            upper = _boundTick(_alignTick(currentTick + tickSpacing, tickSpacing), tickSpacing);
        }

        return _mintStudentPositionWithRange(
            liquidity,
            ethAmountMax,
            tokenAmountMax,
            lower,
            upper
        );
    }

    function _mintStudentPositionWithRange(
        uint256 liquidity,
        uint128 ethAmountMax,
        uint128 tokenAmountMax,
        int24 tickLower,
        int24 tickUpper
    ) internal returns (uint256 tokenId) {
        if (liquidity == 0 || ethAmountMax == 0 || tokenAmountMax == 0) {
            revert ZeroAmount();
        }

        PoolKey memory key = _studentPoolKey();
        tokenId = positionManager.nextTokenId();

        bytes memory actions = abi.encodePacked(
            bytes1(ACTION_MINT_POSITION),
            bytes1(ACTION_SETTLE_PAIR),
            bytes1(ACTION_SWEEP)
        );
        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            key,
            tickLower,
            tickUpper,
            liquidity,
            ethAmountMax,
            tokenAmountMax,
            address(this),
            new bytes(0)
        );
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(this));

        positionManager.modifyLiquidities{value: ethAmountMax}(
            abi.encode(actions, params),
            block.timestamp
        );
    }

    function _settleOrTake(Currency currency, int128 amount) internal {
        if (amount > 0) {
            poolManager.take(currency, address(this), _abs(amount));
            return;
        }

        if (amount < 0) {
            uint256 amountToSettle = _abs(amount);
            if (Currency.unwrap(currency) == address(0)) {
                poolManager.settle{value: amountToSettle}();
            } else {
                poolManager.sync(currency);
                require(
                    IERC20(Currency.unwrap(currency)).transfer(
                        address(poolManager),
                        amountToSettle
                    ),
                    "ERC20 settle transfer failed"
                );
                poolManager.settle();
            }
        }
    }

    function _boundedTokenInput() internal view returns (uint128) {
        uint256 balance = yourToken.balanceOf(address(this));
        uint256 amount = balance / 2;
        if (amount == 0) {
            amount = balance;
        }

        return uint128(amount);
    }

    function _boundedEthInput() internal view returns (uint128) {
        uint256 balance = address(this).balance;
        uint256 amount = balance / 4;
        if (amount == 0) {
            amount = balance;
        }

        return uint128(amount);
    }

    function _setupPermit2Approval(address token) internal {
        address permit2 = positionManager.permit2();
        IERC20(token).approve(permit2, type(uint256).max);
        IPermit2AllowanceTransfer(permit2).approve(
            token,
            address(positionManager),
            type(uint160).max,
            type(uint48).max
        );
    }

    function _studentPoolKey() internal view returns (PoolKey memory) {
        return
            PoolKey({
                currency0: Currency.wrap(address(0)),
                currency1: Currency.wrap(address(yourToken)),
                fee: POOL_FEE,
                tickSpacing: POOL_FEE.isDynamicFee()
                    ? int24(60)
                    : int24((POOL_FEE / 100) * 2),
                hooks: IHooks(address(0))
            });
    }

    function _dummyPoolKey() internal view returns (PoolKey memory) {
        return
            PoolKey({
                currency0: Currency.wrap(address(0)),
                currency1: Currency.wrap(address(dummyToken)),
                fee: POOL_FEE,
                tickSpacing: POOL_FEE.isDynamicFee()
                    ? int24(60)
                    : int24((POOL_FEE / 100) * 2),
                hooks: IHooks(address(0))
            });
    }

    function _abs(int128 value) internal pure returns (uint256) {
        return uint256(uint128(value < 0 ? -value : value));
    }

    function _alignTick(
        int24 tick,
        int24 tickSpacing
    ) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) {
            compressed -= 1;
        }
        return compressed * tickSpacing;
    }

    function _boundTick(
        int24 tick,
        int24 tickSpacing
    ) internal pure returns (int24) {
        int24 minTick = _alignTick(TickMath.MIN_TICK, tickSpacing);
        int24 maxTick = _alignTick(TickMath.MAX_TICK, tickSpacing);

        if (tick < minTick) {
            return minTick;
        }
        if (tick > maxTick) {
            return maxTick;
        }
        return tick;
    }
}

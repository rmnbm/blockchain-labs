import { network } from "hardhat";

const AMM_EVALUATOR = "0x2692eDF2E8d21EF98Dc4dfe29Ff62d91Ea6e36b9";
const POOL_FEE = 500;
const TICK_SPACING = 10;
const DUMMY_RANGE_HALF_WIDTH = 600;
const STUDENT_TICK_LOWER = -600;
const STUDENT_TICK_UPPER = 600;
const Q96 = 2n ** 96n;
const Q96_FLOAT = 7.922816251426434e28;

const ACTION_MINT_POSITION = 0x02;
const ACTION_SETTLE_PAIR = 0x0d;
const ACTION_SWEEP = 0x14;

async function main() {
  const { ethers, networkName } = await network.connect();
  console.log(`Running AMM 101 solution on ${networkName}`);

  const [signer] = await ethers.getSigners();
  const evaluator = new ethers.Contract(
    AMM_EVALUATOR,
    [
      "function dummyToken() view returns (address)",
      "function positionManagerV4() view returns (address)",
      "function stateViewV4() view returns (address)",
      "function ex6a_getTickerAndSupply()",
      "function readTicker(address) view returns (string)",
      "function readSupply(address) view returns (uint256)",
      "function submitErc20(address)",
      "function ex6b_testErc20TickerAndSupply()",
      "function ex7_tokenIsTradableOnUniswap()",
      "function ex1_showIHaveTokens()",
      "function ex2_showIProvidedLiquidity(uint256)",
      "function submitExercice(address)",
      "function ex8_contractCanSwapVsEth()",
      "function ex9_contractCanSwapVsDummyToken()",
      "function ex10_contractCanProvideLiquidity()",
      "function ex11_contractCansLiquidity()",
    ],
    signer
  );

  const dummyTokenAddress = await evaluator.dummyToken();
  const positionManagerAddress = await evaluator.positionManagerV4();
  const stateViewAddress = await evaluator.stateViewV4();

  const positionManager = await ethers.getContractAt(
    "IPositionManagerExtended",
    positionManagerAddress
  );
  const stateView = await ethers.getContractAt("IStateView", stateViewAddress);

  console.log(`Signer: ${signer.address}`);
  console.log(`Evaluator: ${AMM_EVALUATOR}`);

  console.log("Requesting assigned ticker and supply...");
  await waitFor(await evaluator.ex6a_getTickerAndSupply());
  const ticker = await evaluator.readTicker(signer.address);
  const supply = await evaluator.readSupply(signer.address);
  console.log(`Assigned ticker: ${ticker}`);
  console.log(`Assigned supply: ${supply.toString()}`);

  console.log("Deploying student ERC20...");
  const tokenFactory = await ethers.getContractFactory("WorkshopToken");
  const token = await tokenFactory.deploy(
    `${ticker} Workshop Token`,
    ticker,
    supply
  );
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();

  console.log("Submitting ERC20 and validating ex6...");
  await waitFor(await evaluator.submitErc20(tokenAddress));
  await waitFor(await evaluator.ex6b_testErc20TickerAndSupply());

  console.log("Deploying AMM exercise contract...");
  const solutionFactory = await ethers.getContractFactory("AMMExerciseSolution");
  const solution = await solutionFactory.deploy(
    tokenAddress,
    dummyTokenAddress,
    positionManagerAddress,
    stateViewAddress
  );
  await solution.waitForDeployment();
  const solutionAddress = await solution.getAddress();

  const bootstrapEthMax = ethers.parseEther("0.0012");
  const exerciseEthMax = ethers.parseEther("0.0004");
  const contractFundingEth = ethers.parseEther("0.0030");
  const dummyBuyEthAmount = ethers.parseEther("0.0006");
  const dummyWalletEthMax = ethers.parseEther("0.0002");

  const contractFundingToken = maxBigInt(
    1n,
    minBigInt(supply / 4n, ethers.parseEther("0.20"))
  );
  const bootstrapTokenMax = maxBigInt(
    1n,
    minBigInt(contractFundingToken / 2n, ethers.parseEther("0.0012"))
  );
  const exerciseTokenMax = maxBigInt(
    1n,
    minBigInt(contractFundingToken / 4n, ethers.parseEther("0.0004"))
  );

  console.log("Funding solution contract...");
  await waitFor(
    await signer.sendTransaction({
      to: solutionAddress,
      value: contractFundingEth,
    })
  );
  await waitFor(await token.transfer(solutionAddress, contractFundingToken));

  const sqrtPriceX96 = calculateSqrtPriceX96FromPrice(1);
  const bootstrapLiquidity = applySafetyMargin(
    getLiquidityForAmounts(
      sqrtPriceX96,
      sqrtRatioAtTick(STUDENT_TICK_LOWER),
      sqrtRatioAtTick(STUDENT_TICK_UPPER),
      bootstrapEthMax,
      bootstrapTokenMax
    ),
    85n
  );
  const exerciseLiquidity = applySafetyMargin(
    getLiquidityForAmounts(
      sqrtPriceX96,
      sqrtRatioAtTick(STUDENT_TICK_LOWER),
      sqrtRatioAtTick(STUDENT_TICK_UPPER),
      exerciseEthMax,
      exerciseTokenMax
    ),
    85n
  );

  if (bootstrapLiquidity === 0n || exerciseLiquidity === 0n) {
    throw new Error(
      "Computed student-pool liquidity is zero. The assigned token supply is too small for the default parameters."
    );
  }

  console.log("Bootstrapping student pool and initial liquidity...");
  await waitFor(
    await solution.bootstrapPoolAndLiquidity(
      sqrtPriceX96,
      bootstrapLiquidity,
      bootstrapEthMax,
      bootstrapTokenMax
    )
  );
  await waitFor(
    await solution.configureExerciseLiquidity(
      exerciseLiquidity,
      exerciseEthMax,
      exerciseTokenMax
    )
  );

  console.log("Validating tradable pool...");
  await waitFor(await evaluator.ex7_tokenIsTradableOnUniswap());

  console.log("Buying dummy tokens for the signer...");
  await waitFor(await solution.buyDummyForOwner(dummyBuyEthAmount));
  await waitFor(await evaluator.ex1_showIHaveTokens());

  console.log("Providing wallet-side liquidity on the dummy/ETH pool...");
  const dummyToken = new ethers.Contract(
    dummyTokenAddress,
    ["function balanceOf(address) view returns (uint256)"],
    signer
  );
  const walletDummyBalance = await dummyToken.balanceOf(signer.address);
  const dummyPoolKey = buildPoolKey(
    ethers.ZeroAddress,
    dummyTokenAddress,
    POOL_FEE,
    TICK_SPACING,
    ethers.ZeroAddress
  );
  const dummyPoolId = poolIdFromKey(dummyPoolKey);
  const slot0 = await stateView.getSlot0(dummyPoolId);
  const currentTick = Number(slot0[1]);
  const tickLower = alignTick(currentTick - DUMMY_RANGE_HALF_WIDTH, TICK_SPACING);
  const tickUpper = alignTick(currentTick + DUMMY_RANGE_HALF_WIDTH, TICK_SPACING);
  const currentSqrtPriceX96 = BigInt(slot0[0].toString());
  const dummyTokenForWalletLp = walletDummyBalance / 2n;
  const dummyWalletLiquidity = applySafetyMargin(
    getLiquidityForAmounts(
      currentSqrtPriceX96,
      sqrtRatioAtTick(tickLower),
      sqrtRatioAtTick(tickUpper),
      dummyWalletEthMax,
      dummyTokenForWalletLp
    ),
    80n
  );

  if (dummyTokenForWalletLp === 0n || dummyWalletLiquidity === 0n) {
    throw new Error(
      "Dummy-token buy amount was too small to create a wallet LP position. Increase dummyBuyEthAmount."
    );
  }

  await approveForPositionManager(
    dummyTokenAddress,
    signer.address,
    positionManagerAddress,
    positionManager
  );

  const dummyLpTokenId = await positionManager.nextTokenId();
  await waitFor(
    await positionManager.modifyLiquidities(
      encodeMintAndSettle(
        dummyPoolKey,
        tickLower,
        tickUpper,
        dummyWalletLiquidity,
        dummyWalletEthMax,
        dummyTokenForWalletLp,
        signer.address
      ),
      deadlineFromNow(),
      { value: dummyWalletEthMax }
    )
  );
  await waitFor(await evaluator.ex2_showIProvidedLiquidity(dummyLpTokenId));

  console.log("Submitting solution contract to evaluator...");
  await waitFor(await evaluator.submitExercice(solutionAddress));

  console.log("Validating contract-side swap and liquidity exercises...");
  await waitFor(await evaluator.ex8_contractCanSwapVsEth());
  await waitFor(await evaluator.ex9_contractCanSwapVsDummyToken());
  await waitFor(await evaluator.ex10_contractCanProvideLiquidity());
  await waitFor(await evaluator.ex11_contractCansLiquidity());

  console.log("AMM 101 workshop solved successfully.");
  console.log(`Student token: ${tokenAddress}`);
  console.log(`Solution contract: ${solutionAddress}`);
}

function buildPoolKey(
  currency0: string,
  currency1: string,
  fee: number,
  tickSpacing: number,
  hooks: string
) {
  return { currency0, currency1, fee, tickSpacing, hooks };
}

function poolIdFromKey(poolKey: ReturnType<typeof buildPoolKey>) {
  const abi = ethers.AbiCoder.defaultAbiCoder();
  return ethers.keccak256(
    abi.encode(
      ["address", "address", "uint24", "int24", "address"],
      [
        poolKey.currency0,
        poolKey.currency1,
        poolKey.fee,
        poolKey.tickSpacing,
        poolKey.hooks,
      ]
    )
  );
}

function encodeMintAndSettle(
  poolKey: ReturnType<typeof buildPoolKey>,
  tickLower: number,
  tickUpper: number,
  liquidity: bigint,
  ethAmountMax: bigint,
  tokenAmountMax: bigint,
  owner: string
) {
  const abi = ethers.AbiCoder.defaultAbiCoder();
  const actions = ethers.solidityPacked(
    ["uint8", "uint8", "uint8"],
    [ACTION_MINT_POSITION, ACTION_SETTLE_PAIR, ACTION_SWEEP]
  );
  const params = [
    abi.encode(
      [
        "tuple(address currency0,address currency1,uint24 fee,int24 tickSpacing,address hooks)",
        "int24",
        "int24",
        "uint256",
        "uint128",
        "uint128",
        "address",
        "bytes",
      ],
      [poolKey, tickLower, tickUpper, liquidity, ethAmountMax, tokenAmountMax, owner, "0x"]
    ),
    abi.encode(["address", "address"], [poolKey.currency0, poolKey.currency1]),
    abi.encode(["address", "address"], [poolKey.currency0, owner]),
  ];

  return abi.encode(["bytes", "bytes[]"], [actions, params]);
}

async function approveForPositionManager(
  tokenAddress: string,
  signerAddress: string,
  positionManagerAddress: string,
  positionManager: any
) {
  const token = await ethers.getContractAt("DummyToken", tokenAddress);
  const permit2Address = await positionManager.permit2();
  const permit2 = await ethers.getContractAt(
    "IPermit2AllowanceTransfer",
    permit2Address
  );

  await waitFor(await token.approve(permit2Address, ethers.MaxUint256));
  await waitFor(
    await permit2.approve(
      tokenAddress,
      positionManagerAddress,
      (2n ** 160n) - 1n,
      (2n ** 48n) - 1n
    )
  );

  console.log(`Permit2 approvals set for ${signerAddress}`);
}

function deadlineFromNow() {
  return Math.floor(Date.now() / 1000) + 3600;
}

function alignTick(tick: number, tickSpacing: number) {
  return Math.floor(tick / tickSpacing) * tickSpacing;
}

function calculateSqrtPriceX96FromPrice(price: number) {
  return BigInt(Math.floor(Math.sqrt(price) * Q96_FLOAT));
}

function sqrtRatioAtTick(tick: number) {
  return BigInt(Math.floor(Math.pow(1.0001, tick / 2) * Q96_FLOAT));
}

function getLiquidityForAmounts(
  sqrtPriceX96: bigint,
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  amount0: bigint,
  amount1: bigint
) {
  let sqrtA = sqrtRatioAX96;
  let sqrtB = sqrtRatioBX96;

  if (sqrtA > sqrtB) {
    [sqrtA, sqrtB] = [sqrtB, sqrtA];
  }

  if (sqrtPriceX96 <= sqrtA) {
    return getLiquidityForAmount0(sqrtA, sqrtB, amount0);
  }

  if (sqrtPriceX96 < sqrtB) {
    const liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtB, amount0);
    const liquidity1 = getLiquidityForAmount1(sqrtA, sqrtPriceX96, amount1);
    return liquidity0 < liquidity1 ? liquidity0 : liquidity1;
  }

  return getLiquidityForAmount1(sqrtA, sqrtB, amount1);
}

function getLiquidityForAmount0(
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  amount0: bigint
) {
  const intermediate = (sqrtRatioAX96 * sqrtRatioBX96) / Q96;
  return (amount0 * intermediate) / (sqrtRatioBX96 - sqrtRatioAX96);
}

function getLiquidityForAmount1(
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  amount1: bigint
) {
  return (amount1 * Q96) / (sqrtRatioBX96 - sqrtRatioAX96);
}

function applySafetyMargin(value: bigint, percent: bigint) {
  return (value * percent) / 100n;
}

function minBigInt(a: bigint, b: bigint) {
  return a < b ? a : b;
}

function maxBigInt(a: bigint, b: bigint) {
  return a > b ? a : b;
}

async function waitFor(tx: any) {
  const receipt = await tx.wait();
  console.log(`  tx mined: ${receipt?.hash}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

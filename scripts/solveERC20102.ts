import { network } from "hardhat";

const WORKSHOP = {
  evaluator: "0x822aF04084720Ade89E34e316c169435bBA9C886",
  claimableToken: "0xD829b447AbABDb689C1F6DC81CCe3d29b37c5992",
};

async function main() {
  const { ethers, networkName } = await network.connect();

  if (networkName !== "sepolia") {
    throw new Error(
      `Unsupported network "${networkName}". This submission is configured for Sepolia only.`
    );
  }

  const [signer] = await ethers.getSigners();
  console.log(`Running ERC20 102 solution on ${networkName}`);
  console.log(`Signer: ${signer.address}`);

  const claimableToken = new ethers.Contract(
    WORKSHOP.claimableToken,
    [
      "function claimTokens()",
      "function approve(address,uint256) returns (bool)",
    ],
    signer
  );
  const evaluator = new ethers.Contract(
    WORKSHOP.evaluator,
    [
      "function ex1_claimedPoints()",
      "function ex2_claimedFromContract()",
      "function ex3_withdrawFromContract()",
      "function ex4_approvedExerciceSolution()",
      "function ex5_revokedExerciceSolution()",
      "function ex6_depositTokens()",
      "function ex7_createERC20()",
      "function ex8_depositAndMint()",
      "function ex9_withdrawAndBurn()",
      "function submitExercice(address)",
    ],
    signer
  );

  console.log("Claiming tokens on the wallet for exercise 1...");
  await waitForTx(await claimableToken.claimTokens());
  await waitForTx(await evaluator.ex1_claimedPoints());

  console.log("Deploying ExerciseSolution...");
  const solutionFactory = await ethers.getContractFactory("ExerciseSolution");
  const solution = await solutionFactory.deploy(WORKSHOP.claimableToken);
  await solution.waitForDeployment();
  const solutionAddress = await solution.getAddress();
  console.log(`ExerciseSolution deployed at ${solutionAddress}`);

  console.log("Submitting solution to the evaluator...");
  await waitForTx(await evaluator.submitExercice(solutionAddress));

  console.log("Validating exercises 2 and 3...");
  await waitForTx(await evaluator.ex2_claimedFromContract());
  await waitForTx(await evaluator.ex3_withdrawFromContract());

  const allowanceAmount = ethers.parseUnits("1000", 18);
  console.log("Granting allowance for exercise 4...");
  await waitForTx(await claimableToken.approve(solutionAddress, allowanceAmount));
  await waitForTx(await evaluator.ex4_approvedExerciceSolution());

  console.log("Revoking allowance for exercise 5...");
  await waitForTx(await claimableToken.approve(solutionAddress, 0));
  await waitForTx(await evaluator.ex5_revokedExerciceSolution());

  console.log("Running evaluator-driven deposit exercises...");
  await waitForTx(await evaluator.ex6_depositTokens());
  await waitForTx(await evaluator.ex7_createERC20());
  await waitForTx(await evaluator.ex8_depositAndMint());
  await waitForTx(await evaluator.ex9_withdrawAndBurn());

  console.log("ERC20 102 workshop solved successfully.");
  console.log(`Solution contract: ${solutionAddress}`);
  console.log(
    `Receipt token: ${await solution.getERC20DepositAddress()}`
  );
}

async function waitForTx(tx: any) {
  const receipt = await tx.wait();
  console.log(`  tx mined: ${receipt?.hash}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

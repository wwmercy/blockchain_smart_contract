const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying TrustlessEscrow...\n");

  const [deployer, client, freelancer, arbiter] = await hre.ethers.getSigners();

  console.log("Deploying with accounts:");
  console.log("Client:", client.address);
  console.log("Freelancer:", freelancer.address);
  console.log("Arbiter:", arbiter.address);

  const TrustlessEscrow = await hre.ethers.getContractFactory("TrustlessEscrow");
  const escrow = await TrustlessEscrow.deploy(
    client.address,
    freelancer.address,
    arbiter.address
  );

  await escrow.waitForDeployment();
  const address = await escrow.getAddress();

  console.log("\n✅ Contract deployed to:", address);
  console.log("\n📋 Save these for the UI:");
  console.log("CONTRACT_ADDRESS =", address);
  console.log("CLIENT =", client.address);
  console.log("FREELANCER =", freelancer.address);
  console.log("ARBITER =", arbiter.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

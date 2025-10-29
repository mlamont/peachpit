const { ethers, upgrades } = require("hardhat");
async function main() {
  const [deployer] = await ethers.getSigners();
  const Peachpit = await ethers.getContractFactory("PeachpitV02");
  console.log("Deploying Peachpit...");
  const peachpit = await upgrades.deployProxy(Peachpit, [deployer.address], {
    initializer: "initialize",
  });
  await peachpit.waitForDeployment();
  console.log("Peachpit deployed to:", await peachpit.getAddress()); // (PPP)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

const { ethers, upgrades } = require("hardhat");
async function main() {
  // const [deployer] = await ethers.getSigners();
  const Peachpit = await ethers.getContractFactory("PeachpitV06");
  console.log("Deploying Peachpit...");
  const peachpit = await upgrades.deployProxy(
    Peachpit,
    ["0x1B23c1D7Ad49C9c3bdCAA4d7696496C87cc777b7"],
    {
      initializer: "initialize",
    }
  );
  await peachpit.waitForDeployment();
  console.log("Peachpit deployed to:", await peachpit.getAddress()); // (PPP)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
